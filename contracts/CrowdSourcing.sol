// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
/*
    Crowdsourcing with milestones, expected logic:
    - There is a general system owner, who owns the crowdsourcing "page"
    - Users can create projects, which other users can fund:
    - Those projects have milestones, upon reaching a certain milestone by a certain date,
    the project creator receives the money. Else (if it's not reached by a certain date),
    all investors are refunded.

    E.g. PC1 creates a project "Cool project" with 3 milestones:
    100 euros by Nov 20
    1000 eur by Nov 30
    10000 eur by Dec 30

    Nov 18
    F1 funds 50 eur, F2 funds 25 eur, F3 Funds 26 Eur
    Nov 19
    F4 funds 50 eur
    Nov 20
    Check for milestone 1 deadline, reached. PC1 gets 151 eur. project not cancelled
    Nov 29
    F1 funds 500 eur, F2 funds 9 eur
    Nov 30
    Check for milestone 2 deadline - not reached. Project cancelled.
    F1 gets 500 eur back, F2 gets 9 eur back, F3, F4 get nothing back.
    PC1 keeps 101 eur from before.
*/

struct Project {
    address creator;
    string name;
    string headerImageUrl;
    string description;
    uint totalFunded;
    uint currentMilestoneIndex;
    Milestone[] milestones;
    bool isActive; // i.e. not cancelled
}

struct Milestone {
    MilestoneInfo info;
    uint totalFunded; // only current milestone total funded, used to transfer money to owner only lol
    address[] funderAddresses;
    mapping(address => uint) funders; // adress amount funded
    bool reached;
}

struct MilestoneInfo {
    uint goalAmount;
    uint deadline;
}

contract CrowdSourcing {
    event ProjectCreated(uint projectIdx);

    event ProjectFunded(
        uint projectIdx,
        uint amount,
        uint totalFunded,
        uint currentMilestoneTotalFunded
    );

    event CurrentMilestoneStatus(
        uint deadline,
        uint goalAmount,
        uint totalFunded,
        uint currentMileStoneTotalFunded
    );

    address public sysOwner;

    Project[] public projects;

    constructor() {
        sysOwner = msg.sender;
    }

    function createProject(
        string memory _name,
        string memory _headerImageUrl,
        string memory _description,
        MilestoneInfo[] memory _milestones
    ) external {
        require(msg.sender != sysOwner, "System owner can't create projects");
        require(_milestones.length > 0, "Must have at least one milestone");
        for (uint i = 0; i < _milestones.length; i++) {
            require(_milestones[i].goalAmount > 0, "Goal amount can't be 0");
            require(
                _milestones[i].deadline > block.timestamp,
                "Deadline can't be in the past"
            );
        }

        Project storage project = projects.push();
        project.creator = msg.sender;
        project.name = _name;
        project.headerImageUrl = _headerImageUrl;
        project.description = _description;
        project.totalFunded = 0;
        project.currentMilestoneIndex = 0;
        project.isActive = true;

        for (uint i = 0; i < _milestones.length; i++) {
            Milestone storage milestone = project.milestones.push();
            milestone.info.goalAmount = _milestones[i].goalAmount;
            milestone.info.deadline = _milestones[i].deadline;
            milestone.totalFunded = 0;
            milestone.reached = false;
        }

        emit ProjectCreated(projects.length);
    }

    function fundProject(uint _projectIdx) external payable {
        require(_projectIdx < projects.length, "Project doesn't exist");
        require(
            msg.value <= msg.sender.balance,
            "You dont have enough money to fund"
        );
        require(msg.value > 0, "Fund amount can't be 0");

        Project storage project = projects[_projectIdx];
        require(project.isActive, "Project must be active to fund");

        Milestone storage currentMilestone = project.milestones[
            project.currentMilestoneIndex
        ];
        require(
            currentMilestone.info.deadline > block.timestamp,
            "You can't fund after deadline"
        );
     
        if (currentMilestone.funders[msg.sender] == 0) {
            currentMilestone.funderAddresses.push(msg.sender);
        }

        currentMilestone.funders[msg.sender] += msg.value;
        currentMilestone.totalFunded += msg.value;
        project.totalFunded += msg.value;

        while(project.totalFunded > currentMilestone.info.goalAmount) {

            uint surplus = project.totalFunded - currentMilestone.info.goalAmount;
            currentMilestone.totalFunded = currentMilestone.info.goalAmount;
            project.totalFunded = currentMilestone.info.goalAmount;
            currentMilestone.funders[msg.sender] -= surplus;
            
            if(project.currentMilestoneIndex == project.milestones.length - 1) {
                project.isActive = false;
                (bool success, ) = msg.sender.call{value: surplus}("");
                require(success, "Failed to return surplus");    
            } else {
                initiateNextMilestone(_projectIdx);
                currentMilestone = project.milestones[project.currentMilestoneIndex];
                currentMilestone.funderAddresses.push(msg.sender);
                currentMilestone.funders[msg.sender] += surplus;
                currentMilestone.totalFunded += surplus;
                project.totalFunded += surplus;
            }
        }

        emit ProjectFunded(
            _projectIdx,
            msg.value,
            project.totalFunded,
            currentMilestone.totalFunded
        );
    }

    function checkCurrentMilestone(uint _projectIdx) external {
        Project storage project = projects[_projectIdx];
        require(project.isActive, "Project must be active");
        Milestone storage currentMilestone = project.milestones[
            project.currentMilestoneIndex
        ];
        require(!currentMilestone.reached, "Milestone should be not reached");

        emit CurrentMilestoneStatus(
            currentMilestone.info.deadline,
            currentMilestone.info.goalAmount,
            project.totalFunded,
            currentMilestone.totalFunded
        );
    }

    //this function will be used only to move onto next milestone once one was completed
    function initiateNextMilestone(uint _projectIdx) private {
        Project storage project = projects[_projectIdx];
        Milestone storage currentMilestone = project.milestones[
            project.currentMilestoneIndex
        ];
        uint moneyAmountToSend = currentMilestone.totalFunded;
        if(project.currentMilestoneIndex > 0) {
            moneyAmountToSend -= project.milestones[project.currentMilestoneIndex - 1].totalFunded;
        }
    
        if (project.totalFunded >= currentMilestone.info.goalAmount) {
            currentMilestone.reached = true;
            sendMoneyToOwner(project.creator, moneyAmountToSend);

            if (project.currentMilestoneIndex < project.milestones.length - 1) {
                project.currentMilestoneIndex++;
            } else {
                // project is "done" after being fully funded
                project.isActive = false;
            }
        } else {
            // cancel if milestone not reached after timestamp
            stopProjectHelper(_projectIdx);
        }
    }

    function sendMoneyToOwner(
        address projectCreator,
        uint moneyAmount
    ) private {
        (bool success, ) = projectCreator.call{value: moneyAmount}("");
        require(success, "Transfer to creator failed");
    }

    function refundMilestone(uint _projectIdx, uint _milestoneIdx) private {
        Project storage project = projects[_projectIdx];
        Milestone storage milestone = project.milestones[_milestoneIdx];

        for (uint i = 0; i < milestone.funderAddresses.length; i++) {
            address funder = milestone.funderAddresses[i];
            uint amount = milestone.funders[funder];

            if (amount > 0) {
                milestone.funders[funder] = 0;
                (bool success, ) = funder.call{value: amount}("");
                require(success, "Refund failed");
            }
        }
    }

    // To stop projects that the sysOwner deems as scams/illega/whatever
    // or for when project owners realize they aren't feasible or smt idk
    function stopProject(uint _projectIdx) external {
        require(
            msg.sender == sysOwner ||
                msg.sender == projects[_projectIdx].creator,
            "Only system owner or project owner can stop projects"
        );
        stopProjectHelper(_projectIdx);
    }

    function stopProjectHelper(uint _projectIdx) private {
        Project storage project = projects[_projectIdx];
        project.isActive = false;
        refundMilestone(_projectIdx, project.currentMilestoneIndex);
    }

    /*
    TODO LIST:
    - daug kitu dalyku. visa logika
    - pratestuot ar tai kas egizstuoja veikia lmao
    */
}
