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
    uint totalFunded;
    uint currentMilestoneIndex;
    Milestone[] milestones;

    bool isActive; // i.e. not cancelled
}

struct Milestone{
    MilestoneInfo info;
    uint totalFunded;
    address[] funderAddresses;
    mapping(address => uint) funders; //adress -> amount funded
    bool reached;
}

struct MilestoneInfo{
    uint goalAmount;
    uint deadline;
}

contract CrowdSourcing {
    address public sysOwner;

    Project[] public projects;

    constructor() {
        sysOwner = msg.sender;
    }

    function createProject(
        string memory _name,
        MilestoneInfo[] memory _milestones
    ) external {
        require(msg.sender != sysOwner, "System owner can't create projects");
        require(_milestones.length > 0, "Must have at least one milestone");

        Project storage project = projects.push();
        project.creator = msg.sender;
        project.name = _name;
        project.totalFunded = 0;
        project.currentMilestoneIndex = 0;
        project.isActive = true;


        for(uint i=0; i< _milestones.length; i++){
            Milestone storage milestone = project.milestones.push();
            milestone.info.goalAmount = _milestones[i].goalAmount;
            milestone.info.deadline = _milestones[i].deadline;
            milestone.totalFunded = 0;
            milestone.reached = false;
        }
    }

    function fundProject (
        uint _projectIdx
    ) external payable {
        require(_projectIdx < projects.length, "Project doesn't exist");
        require(msg.value <= msg.sender.balance, "You dont have enough money to fund");
        require(msg.value > 0, "Fund amount can't be 0");

        Project storage project = projects[_projectIdx];
        require(project.isActive, "Project must be active to fund");

        Milestone storage currentMilestone = project.milestones[project.currentMilestoneIndex];
        require(currentMilestone.info.deadline > block.timestamp, "You can't fund after deadline");

        currentMilestone.funders[msg.sender] += msg.value;
        currentMilestone.totalFunded += msg.value;
        project.totalFunded += msg.value;
	if(currentMilestone.funders[msg.sender] == 0) {
    		currentMilestone.funderAddresses.push(msg.sender);
	}
    }

    function checkMilestone(
        uint _projectIdx
    ) external  {
        Project storage project = projects[_projectIdx];
        Milestone storage currentMilestone = project.milestones[project.currentMilestoneIndex];
        require(project.isActive, "Project must be active");
        require(!currentMilestone.reached, "Milestone should be not reached");
        require(block.timestamp >= currentMilestone.info.deadline, "Can only chekck after milestone");
// also gal cia geriau perdaryt ne su ifais o su require?? kzn as nzn kada even naudot ifus
            if(currentMilestone.totalFunded >= currentMilestone.info.goalAmount) {
                currentMilestone.reached = true;
                (bool success, ) = project.creator.call{value: currentMilestone.totalFunded}("");
                require(success, "Transfer to creator failed");
                // todo: figure out how to make this send money to the owner lol
                // project.creator
                if(project.currentMilestoneIndex < project.milestones.length - 1){
                    currentMilestone.reached = true;
                    project.currentMilestoneIndex++;
                } else {
                    // close project after all milestones
                    project.isActive = false;
                    
                }
            } else {
            // cancel if milestone not reached after timestamp
            project.isActive = false;
            refundMilestone(_projectIdx, project.currentMilestoneIndex);
        }
    }

    function refundMilestone(
        uint _projectIdx,
        uint _milestoneIdx
    ) private {
        Project storage project = projects[_projectIdx];
        Milestone storage milestone = project.milestones[_milestoneIdx];

        for(uint i=0; i<milestone.funderAddresses.length; i++){
            address funder = milestone.funderAddresses[i];
            uint amount = milestone.funders[funder];

            if(amount > 0) {
                milestone.funders[funder] = 0;
                (bool success, ) = funder.call{value: amount}("");
                require(success, "Refund failed");
            }
        }
    }

    /*
    TODO LIST:
    - visi todo's check milestone
    - refundinimo funckijos
    - kzn gal reik padaryt, kad sysowneris galetu killint projektus jeigu kzn jie scam ir auto refundintu visus pinigus? idk
    - daug kitu dalyku. visa logika
    - pratestuot ar tai kas egizstuoja veikia lmao
    */
}
