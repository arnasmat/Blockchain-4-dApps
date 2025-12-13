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

struct ProjectView {
    address creator;
    string name;
    string headerImageUrl;
    string description;
    uint totalFunded;
    uint currentMilestoneIndex;
    bool isActive;
    uint index;
}

struct MilestoneView {
    uint goalAmount;
    uint deadline;
    uint index;
    uint totalFunded;
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
    event ProjectCreated(uint projectIndex);

    event ProjectFunded(
        uint projectIndex,
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

    event ProjectStatus(bool isActive);

    address public sysOwner;

    Project[] public projects;

    constructor() {
        sysOwner = msg.sender;
    }

    function createProject(
        string memory name,
        string memory headerImageUrl,
        string memory description,
        MilestoneInfo[] memory milestones
    ) external {
        require(msg.sender != sysOwner, "System owner can't create projects");

        Project storage project = projects.push();
        project.creator = msg.sender;
        project.name = name;
        project.headerImageUrl = headerImageUrl;
        project.description = description;
        project.totalFunded = 0;
        project.currentMilestoneIndex = 0;
        project.isActive = true;

        addNewMilestones(projects.length - 1, milestones);

        emit ProjectCreated(projects.length - 1);
    }

    function fundProject(uint projectIndex) external payable {
        require(projectIndex < projects.length, "Project doesn't exist");
        require(
            msg.value <= msg.sender.balance,
            "You dont have enough money to fund"
        );
        getProjectInfo(projectIndex);

        Project storage project = projects[projectIndex];
        if(!project.isActive) {
            return;
        }
        require(msg.sender !=  project.creator, "Project creator cannot fund its own projects");
        require(msg.value > 0, "Fund amount can't be 0");
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

        while (project.totalFunded > currentMilestone.info.goalAmount) {
            uint surplus = project.totalFunded -
                currentMilestone.info.goalAmount;
            currentMilestone.totalFunded = currentMilestone.info.goalAmount;
            project.totalFunded = currentMilestone.info.goalAmount;
            currentMilestone.funders[msg.sender] -= surplus;

            if (
                project.currentMilestoneIndex == project.milestones.length - 1
            ) {
                project.isActive = false;
                (bool success, ) = msg.sender.call{value: surplus}("");
                require(success, "Failed to return surplus");
            } else {
                initiateNextMilestone(projectIndex);
                currentMilestone = project.milestones[
                    project.currentMilestoneIndex
                ];
                currentMilestone.funderAddresses.push(msg.sender);
                currentMilestone.funders[msg.sender] += surplus;
                currentMilestone.totalFunded += surplus;
                project.totalFunded += surplus;
            }
        }

        emit ProjectFunded(
            projectIndex,
            msg.value,
            project.totalFunded,
            currentMilestone.totalFunded
        );
    }

    function checkCurrentMilestone(uint projectIndex) external {
        require(projectIndex < projects.length, "Invalid projects index");

        Project storage project = projects[projectIndex];
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
    function initiateNextMilestone(uint projectIndex) private {
        Project storage project = projects[projectIndex];
        Milestone storage currentMilestone = project.milestones[
            project.currentMilestoneIndex
        ];
        uint moneyAmountToSend = currentMilestone.totalFunded;
        if (project.currentMilestoneIndex > 0) {
            moneyAmountToSend -= project
                .milestones[project.currentMilestoneIndex - 1]
                .totalFunded;
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
            stopProjectHelper(projectIndex);
        }
    }

    function sendMoneyToOwner(
        address projectCreator,
        uint moneyAmount
    ) private {
        (bool success, ) = projectCreator.call{value: moneyAmount}("");
        require(success, "Transfer to creator failed");
    }

    function refundMilestone(uint projectIndex, uint milestoneIdx) private {
        Project storage project = projects[projectIndex];
        Milestone storage milestone = project.milestones[milestoneIdx];

        for (uint i = 0; i < milestone.funderAddresses.length; i++) {
            address funder = milestone.funderAddresses[i];
            uint amount = milestone.funders[funder];

            if (amount > 0) {
                milestone.funders[funder] = 0;
                (bool success, ) = funder.call{value: amount}("");
                require(success, "Refund failed");
                project.totalFunded -= amount;
                milestone.totalFunded -= amount;
            }
        }
    }

    // To stop projects that the sysOwner deems as scams/illega/whatever
    // or for when project owners realize they aren't feasible or smt idk
    function stopProject(uint projectIndex) external {
        require(
            msg.sender == sysOwner ||
                msg.sender == projects[projectIndex].creator,
            "Only system owner or project owner can stop projects"
        );
        stopProjectHelper(projectIndex);
    }

    function stopProjectHelper(uint projectIndex) private {
        Project storage project = projects[projectIndex];
        require(project.isActive, "Cannot stop inactive project");
        project.isActive = false;
        refundMilestone(projectIndex, project.currentMilestoneIndex);
    }

    function addNewMilestones(
        uint projectIndex,
        MilestoneInfo[] memory milestones
    ) public {
        require(projectIndex < projects.length, "Invalid projects index");
        Project storage project = projects[projectIndex];
        require(
            project.isActive,
            "Cannot add new milestones to inactive project"
        );
        require(
            project.creator == msg.sender,
            "Only project creator can add new milestones"
        );
        require(milestones.length > 0, "Must have at least one milestone");
        for (uint i = 0; i < milestones.length; i++) {
            require(milestones[i].goalAmount > 0, "Goal amount can't be 0");
            require(
                milestones[i].deadline > block.timestamp,
                "Deadline can't be in the past"
            );
            if (i > 0) {
                require(
                    milestones[i].goalAmount > milestones[i - 1].goalAmount,
                    "Milestone goals should be increasing"
                );
                require(
                    milestones[i].deadline > milestones[i - 1].deadline,
                    "Milestone deadlines should be increasing"
                );
            }
            if (project.milestones.length > 0) {
                require(
                    milestones[i].goalAmount >
                        project
                            .milestones[project.milestones.length - 1]
                            .info
                            .goalAmount,
                    "Milestone goals should be increasing"
                );
                require(
                    milestones[i].deadline >
                        project
                            .milestones[project.milestones.length - 1]
                            .info
                            .deadline,
                    "Milestone deadlines should be increasing"
                );
            }
            Milestone storage milestone = project.milestones.push();
            milestone.info.goalAmount = milestones[i].goalAmount;
            milestone.info.deadline = milestones[i].deadline;
            milestone.totalFunded = 0;
            milestone.reached = false;
        }
    }

    function deactivateProjectsWithExpiredDeadlines() external {
        require(
            msg.sender == sysOwner,
            "Only sysOwner can deactivate projects"
        );
        for (uint i = 0; i < projects.length; i++) {
            Project storage project = projects[i];
            Milestone storage currentMilestone = project.milestones[
                project.currentMilestoneIndex
            ];
            if (
                project.isActive &&
                currentMilestone.info.deadline < block.timestamp
            ) {
                stopProjectHelper(i);
            }
        }
    }

    //getters
    function getProjectInfo(
        uint projectIndex
    ) public returns (ProjectView memory) {
        require(projectIndex < projects.length, "Invalid projects index");
        Project storage project = projects[projectIndex];
        if (
            project.milestones[project.currentMilestoneIndex].info.deadline <
            block.timestamp &&
            project.isActive
        ) {
            stopProjectHelper(projectIndex);
        }
        ProjectView memory tempProject;
        tempProject.creator = projects[projectIndex].creator;
        tempProject.name = projects[projectIndex].name;
        tempProject.headerImageUrl = projects[projectIndex].headerImageUrl;
        tempProject.description = projects[projectIndex].description;
        tempProject.totalFunded = projects[projectIndex].totalFunded;
        tempProject.currentMilestoneIndex = projects[projectIndex]
            .currentMilestoneIndex;
        tempProject.isActive = projects[projectIndex].isActive;
        tempProject.index = projectIndex;
        emit ProjectStatus(project.isActive);
        return tempProject;
    }

    function getCurrentMilestoneInfo(
        uint projectIndex
    ) public returns (MilestoneInfo memory) {
        require(projectIndex < projects.length, "Invalid projects index");
        Project storage project = projects[projectIndex];
        if (
            project.milestones[project.currentMilestoneIndex].info.deadline <
            block.timestamp &&
            project.isActive
        ) {
            stopProjectHelper(projectIndex);
        }
        return project.milestones[project.currentMilestoneIndex].info;
    }

    function getCurrentMilestoneFunders(
        uint projectIndex
    ) external view returns (address[] memory) {
        Project storage project = projects[projectIndex];
        Milestone storage currentMilestone = project.milestones[
            project.currentMilestoneIndex
        ];
        return currentMilestone.funderAddresses;
    }

    function getallMilestonesInfo(
        uint projectIndex
    ) external view returns (MilestoneInfo[] memory) {
        require(projectIndex < projects.length, "Invalid projects index");
        Project storage project = projects[projectIndex];
        MilestoneInfo[] memory milestoneInfo = new MilestoneInfo[](
            project.milestones.length
        );
        for (uint i = 0; i < project.milestones.length; i++) {
            milestoneInfo[i] = project.milestones[i].info;
        }
        return milestoneInfo;
    }

    function getAllActiveProjects()
        external
        view
        returns (ProjectView[] memory)
    {
        uint activeProjectsCount = 0;
        for (uint i = 0; i < projects.length; i++) {
            if (projects[i].isActive) {
                activeProjectsCount++;
            }
        }

        ProjectView[] memory tempProjects = new ProjectView[](
            activeProjectsCount
        );

        uint index = 0;
        for (uint i = 0; i < projects.length; i++) {
            if (projects[i].isActive) {
                ProjectView memory tempProject;
                tempProject.creator = projects[i].creator;
                tempProject.name = projects[i].name;
                tempProject.headerImageUrl = projects[i].headerImageUrl;
                tempProject.description = projects[i].description;
                tempProject.totalFunded = projects[i].totalFunded;
                tempProject.currentMilestoneIndex = projects[i].currentMilestoneIndex;
                tempProject.isActive = projects[i].isActive;
                tempProject.index = i;
                tempProjects[index] = tempProject;
                index++;
            }
        }
        return tempProjects;
    }
}
