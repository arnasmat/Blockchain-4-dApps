# dCrowd
dCrowd is a decentralized ethereum smart contract-based crowdfunding/crowdsourcing application with an [Android application for a frontend](https://github.com/arnasmat/dCrowd/tree/main)

# Working principles
The dCrowd application works on these key principles:
- There is one general system owner who launched the contract and can stop projects abruptly. This is to prevent malicious users from abusing the platform in case of scams or illegal activity.
- The system owner can NOT create projects. This is to prevent abuse of power.
- All other users can create and fund projects.
- Users can not fund their own projects, this is to prevent abuse. However, they can stop their and only their projects abruptly themselves.
- !! All projects must have a name and description and an optional header image for better visibilty and visualization. They also must have one or more milestones with a funding goal and a deadline for the milestone.
- Milestones must be provided in increasing order of funding goal and deadline.
- If a milestone is reached before the milestone's deadline, the project owner receives the funded milestone amount and the next milestone is started.
- If a milestone is not reached before the milestone's deadline, all funders are refunded and the project is no longer active.
- If the last milestone is reached, the project is no longer active.
- If funding causes a milestone to be exceeded, the surplus is automatically given to the next milestone (or is refunded if that was the last milestones).
- Only active projects are shown in the app's "feed" and can be funded.

# Set up (for testing)
Prerequisites: set up [ganache-cli and truffle](https://archive.trufflesuite.com/docs/truffle/how-to/install/)
1. Clone the repository

2. Run `ganache-cli` in one terminal and `truffle migrate` in another in the cloned directory.

Alternatively, deploy it on the Ethereum test network

### We recommend interacting with the application via the [android application](https://github.com/arnasmat/dCrowd/tree/main)
