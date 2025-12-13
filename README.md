# dCrowd
dCrowd is a decentralized ethereum smart contract-based crowdfunding/crowdsourcing application with an [Android application for a frontend](https://github.com/arnasmat/dCrowd/tree/main)

<img width="250" alt="Multiple projects in the list screen" src="https://github.com/user-attachments/assets/4cdc41ac-2c07-4628-a59d-99c21922c4f6" />
<img width="250" alt="Project creation screen" src="https://github.com/user-attachments/assets/1c066e6b-68ba-4383-bd6d-63a990700ed2" />
<img width="250" alt="Halfway funded project" src="https://github.com/user-attachments/assets/2c4e0285-fb8a-41a4-8391-7412fbeb0545" />

(Photos from the [android application repo](https://github.com/arnasmat/dCrowd/tree/main). More photos there.)

# Smart contract business model
<img width="858" height="1332" alt="image" src="https://github.com/user-attachments/assets/f828ef38-a912-42d4-af40-bfb3813fcee0" />
1. There are 4 types of entities in our business model of crowdfunding smart contract
   - System owner is the person who deployed the smart contract and can stop any project, but not create one. There is only one system owner in our scenario.
   - Smart contract runs on the blockchain. It can create and store project classes and hold data about them, including milestones goal amounts with deadlines, accounts who created the project, who funded it and how much money each account spend on that particular project. It stores funds and can return the back to senders (only latest milestone) if project was cancelled or transfer funds to the project creator after completing milestone on time.
   - Project owner is an account which sucessfule create project(s) using createProject() function. That person receives funds after each completed milestone on time and can cancel their project, but cannot fund it. If they cancel project, the funds of latest milestone are given back to the funder.
   - Funder is an account which transfer money to smart contract using fundProject() function. Funder sends selected amount of etheureum to selected project. Funder cannot retrieve their money, if they donate more than the milestone amount, these funds are being trasnfered to the next milestone. Surplus amount in case of overfunding last milestone is being autmatically returned to funder by smart contract itself, also if the project of which one of the most recent milestone donators was the funder itself, they get that money back automatically from smart contract.

# Smart contract external functions
These are the functions which are public / external and can be called by developers, who establish connection with the smart contract running on blockchain:
### `createProject(string name, string headerImageUrl, string description, MilestoneInfo[] milestones)`
Takes name, headerImageUrl, desription for the project, and the list of milestones info. Milestones goal amounts and dedalines can only go into increasing order. System owner cannot call this function.
### `fundProject(uint projectIndex)`
Takes the project index, which is used to fund the corresponding project. Project creators cannot fund their own projects. The message value should be more than zero and the fundable project must be active. If project with expired deadline is funded, money is returned back to funder and the project is stopped.
### `checkCurrentMilestone(uint projectIndex)`
Takes the project index and returns the event with info about the current milestone of corresponding project.
### `stopProject(uint projectIndex)`
Takes the project index and deactivates the corresponding project, returning the amount of ethereum which was used to fund its most recent milestone back to the funders. Cal only be called by system owner and project creators. 
### `addNewMilestones(uint projectIndex, MilestoneInfo[] milestones)`
Takes the project index and adds new milestones to it. Can be called only by the project creator. The project on which new milestones are added must be active. Also, the milestones info must follow the rule of increasing deadlines and goal amounts compared to previously created milestones. 
### `deactivateProjectsWithExpiredDeadlines()`
Does not take any parameters and can be exclusively called only by system owner to check for projects with expired deadlines and deactivate them (other functions that do this are private and are called by fundProject() and getProjectInfo()). The idea of this function is to implement it as a cron-job and run it on a server and call it few times in a day using system owner account to deactivate expired projects and let other uses save gas.
### `getProjectInfo(uint projectIndex)`
Takes the project index and returns both the event whether current project is active and class with the information about corresponding project. If it detected that the projectis active and have exceeded the deadline, it stops the project.
### `getCurrentMilestoneInfo(uint projectIndex)`
Takes the project index and returns the class with info about the current milestone of the corresponding project. If it detected that the project is still active and have exceeded the deadline, it stops the project.
### `getCurrentMilestoneFunders(uint projectIndex)`
Takes the project index and returns the array with addresses of funders who funded the most recent milestone of the corresponding project. If it detected that the project is still active and have exceeded the deadline, it stops the project.
### `getallMilestonesInfo(uint projectIndex)`
Takes the project index and returns the array of classes with info about all of the milestones of the corresponding project.
### `getAllActiveProjects()`
Returns the array with classes containing all active projects information. Can be used in applications to retrieve and display all current active projects.

  
# Working principles
The dCrowd application works on these key principles:
- There is one general system owner who launched the contract and can stop projects abruptly. This is to prevent malicious users from abusing the platform in case of scams or illegal activity.
- The system owner can NOT create projects. This is to prevent abuse of power.
- All other users can create and fund projects.
- Users can not fund their own projects, this is to prevent abuse. However, they can stop their and only their projects abruptly themselves.
- !! All projects must have a name and description and an optional header image for better visibilty and visualization. They also must have one or more milestones with a funding goal and a deadline for the milestone.
- Milestones must be provided in increasing order of funding goal and deadline (because eacah milestone represent the amount of money that must be raised up until that particular deaadlina and not the amoun of miney exclusive for every milestone, e.g. if milestones are 100, 200, 300, it means that after completing every milestone project creator will receive 100 money to their account, and after all of them they will have total number of 300 in funds, not 600).
- If a milestone is reached before the milestone's deadline, the project owner receives the amount suitable for this milestone (current milestone goal - previous milestone goal) and the next milestone is started.
- If a milestone is not reached before the milestone's deadline, all funders are refunded and the project is no longer active.
- If the last milestone is reached, the project is no longer active.
- If funding causes a milestone to be exceeded, the surplus is automatically given to the next milestone (or is refunded if that was the last milestones).
- Only active projects are shown in the app's "feed" and can be funded.
- Funding a project whose deadline is expired should remove it from the active projects feed if it wasn't already removed (the deadline check does not run on function returning all all active projects in order to lower gas fees for users. Ideally, the project creator / system owner should disable the project themselves).

# Set up (for testing)
Prerequisites: set up [ganache-cli and truffle](https://archive.trufflesuite.com/docs/truffle/how-to/install/)
1. Clone the repository

2. Run `ganache-cli` in one terminal and `truffle migrate` in another in the cloned directory.

Alternatively, deploy it on the Ethereum test network

### We recommend interacting with the application via the [android application](https://github.com/arnasmat/dCrowd/tree/main)


## Useful commands for testing
(Note: if ganache-cli is hosted not on localhost, you may have to change the url)
Increase time by 1 day
```
curl -X POST --data '{"jsonrpc":"2.0","method":"evm_increaseTime","params":[1728000],"id":1}' http://localhost:8545
```

Mine a block
```
curl -X POST --data '{"jsonrpc":"2.0","method":"evm_mine","params":[],"id":1}' http://localhost:8545
```
