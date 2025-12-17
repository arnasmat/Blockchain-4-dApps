const CrowdSourcing = artifacts.require("CrowdSourcing");

contract("CrowdSourcing", (accounts) => {
    let crowdSourcingContract;
    let transaction;

    before(async () => {
        crowdSourcingContract = await CrowdSourcing.deployed();
    });

//testuoja projekto sukurima
it("create project", async () => {
  transaction = await crowdSourcingContract.createProject("Testinis projektas", "Nuotrauka.url", "Testavimas", [[100, Math.floor(Date.now() / 1000) + 100000], [200, Math.floor(Date.now() / 1000) + 200000], [300, Math.floor(Date.now() / 1000) + 300000]], {from: accounts[1]});

  const project = await crowdSourcingContract.getProjectInfo.call(0);

  assert.equal(project.isActive, true, "Project should be active");
  assert.equal(project.index, 0, "Incorrect project index");
  assert.equal(transaction.logs[0].event, "ProjectCreated", "Project was not created");
  assert.equal(project.totalFunded, 0, "Incorrect funded amount");
  assert.equal(project.currentMilestoneIndex, 0, "Incorrect milestone index");
  });

//testuoja projekto fundinima
it("fund project", async () => {
  await crowdSourcingContract.fundProject(0, {from: accounts[2], value: 10});

  const project = await crowdSourcingContract.getProjectInfo.call(0);
  const milestoneFunders = await crowdSourcingContract.getCurrentMilestoneFunders(0);

  assert.equal(project.isActive, true, "Project should be active");
  assert.equal(project.index, 0, "Incorrect project index");
  assert.equal(project.totalFunded, 10, "Incorrect funded amount");
  assert.equal(project.currentMilestoneIndex, 0, "Incorrect milestone index");
  assert.equal(milestoneFunders[0], accounts[2], "Incorrect funder account");
  });

//testuoja projekto fundinima antrakart
it("fund again", async () => {
  await crowdSourcingContract.fundProject(0, {from: accounts[3], value: 15});

  const project = await crowdSourcingContract.getProjectInfo.call(0);
  const milestoneFunders = await crowdSourcingContract.getCurrentMilestoneFunders(0);

  assert.equal(project.isActive, true, "Project should be active");
  assert.equal(project.index, 0, "Incorrect project index");
  assert.equal(project.totalFunded, 25, "Incorrect funded amount");
  assert.equal(project.currentMilestoneIndex, 0, "Incorrect milestone index");
  assert.equal(milestoneFunders[0], accounts[2], "Incorrect funder account");
  assert.equal(milestoneFunders[1], accounts[3], "Incorrect funder account");
});

//testuoja milestono completinima
it("complete milestone", async () => {
  await crowdSourcingContract.fundProject(0, {from: accounts[3], value: 100});

  const project = await crowdSourcingContract.getProjectInfo.call(0);
  const milestoneFunders = await crowdSourcingContract.getCurrentMilestoneFunders(0);

  assert.equal(project.isActive, true, "Project should be active");
  assert.equal(project.index, 0, "Incorrect project index");
  assert.equal(project.totalFunded, 125, "Incorrect funded amount");
  assert.equal(project.currentMilestoneIndex, 1, "Incorrect milestone index");
  assert.equal(milestoneFunders[0], accounts[3], "Incorrect funder account");
});

//testuoja projekto pabaigima (+ keli milestones ivykdomi vienu metu + overshootinamas end goalas)
it("complete project by overshooting", async () => {
  await crowdSourcingContract.fundProject(0, {from: accounts[2], value: 200});

  const project = await crowdSourcingContract.getProjectInfo.call(0);
  const milestoneFunders = await crowdSourcingContract.getCurrentMilestoneFunders(0);

  assert.equal(project.isActive, false, "Project should be inactive");
  assert.equal(project.index, 0, "Incorrect project index");
  assert.equal(project.totalFunded, 300, "Incorrect funded amount");
  assert.equal(project.currentMilestoneIndex, 2, "Incorrect milestone index");
  assert.equal(milestoneFunders[0], accounts[2], "Incorrect funder account");
});

//testuoja antro projekto ir nauju milestonu papildomai and sukurto projekto pridejima
it("add new milestones", async () => {
  await crowdSourcingContract.createProject("Testinis projektas2", "Nuotrauka.url", "Testavimas", [[100, Math.floor(Date.now() / 1000) + 100000], [200, Math.floor(Date.now() / 1000) + 200000]], {from: accounts[1]});
  
  const project = await crowdSourcingContract.getProjectInfo.call(1);
  let milestones = await crowdSourcingContract.getallMilestonesInfo(1);
  
  assert.equal(project.isActive, true, "Project should be inactive after stopping");
  assert.equal(project.totalFunded, 0, "Incorrect funded amount");
  assert.equal(project.index, 1, "Incorrect project index");
  assert.equal(milestones.length, 2, "Incorrect milestones length");

  await crowdSourcingContract.addNewMilestones(1, [[300, Math.floor(Date.now() / 1000) + 300000]], {from: accounts[1]});
  milestones = await crowdSourcingContract.getallMilestonesInfo(1);

  assert.equal(project.isActive, true, "Project should be inactive after stopping");
  assert.equal(project.totalFunded, 0, "Incorrect funded amount");
  assert.equal(project.index, 1, "Incorrect project index");
  assert.equal(milestones.length, 3, "Incorrect milestones length");

});

//testuoja projekto stabdyma
it("stop project", async () => {
  await crowdSourcingContract.fundProject(1, {from: accounts[2], value: 50});
  
  let project = await crowdSourcingContract.getProjectInfo.call(1);

  assert.equal(project.isActive, true, "Project should be inactive after stopping");
  assert.equal(project.index, 1, "Incorrect project index");
  assert.equal(project.totalFunded, 50, "Incorrect funded amount");

  const balanceBefore = web3.utils.toBN(await web3.eth.getBalance(accounts[2]));
  await crowdSourcingContract.stopProject(1, {from: accounts[1]});
  const balanceAfter = web3.utils.toBN(await web3.eth.getBalance(accounts[2]));
  project = await crowdSourcingContract.getProjectInfo.call(1);
  
  assert.equal(project.isActive, false, "Project should be inactive after stopping");
  assert.equal(project.index, 1, "Incorrect project index");
  assert.equal(project.totalFunded, 0, "Incorrect funded amount");
  assert.equal(balanceAfter.sub(balanceBefore).toNumber(), 50, "Funder should be refunded");
});

});
