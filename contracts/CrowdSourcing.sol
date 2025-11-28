// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;
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
    mapping(address funderAddress => uint amount) funders;
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
}