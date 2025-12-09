const CrowdSourcing = artifacts.require("CrowdSourcing");

contract("CrowdSourcing", (accounts) => {
    let crowdSourcingContract;
    let transaction;

    before(async () => {
        crowdSourcingContract = await CrowdSourcing.deployed();
    });

    //testuoja projekto sukurima
it("create project", async () => {
    transaction = await crowdSourcingContract.createProject("Testinis projektas", "Nuotrauka.url", "Testavimas", [[100, Math.floor(Date.now() / 1000) + 100000], [200, Math.floor(Date.now() / 1000) + 200000]], {from: accounts[1]});

    assert.equal(transaction.logs[0].event, "ProjectCreated", "Project was not created");
    assert.equal(transaction.logs[0].args.projectIndex, 0, "Wrong project index");
  });

    //testuoja projekto fundinima
it("fund project", async () => {
    transaction = await crowdSourcingContract.fundProject(0, {from: accounts[1], value: 10});

  const event = transaction.logs[0];

  assert.equal(event.event, "ProjectFunded", "Project was not funded");
  assert.equal(event.args.projectIndex, 0, "Wrong project index");
  assert.equal(event.args.amount, 10, "Wrong funded amount");
  assert.equal(event.args.totalFunded, 10, "Wrong total project funding");
  assert.equal(event.args.currentMilestoneTotalFunded, 10, "Wrong milestone total funding");
  });

//testuoja projekto fundinima antrakart
it("fund again", async () => {
  transaction = await crowdSourcingContract.fundProject(0, {from: accounts[2], value: 15});

  const event = transaction.logs[0];

  assert.equal(event.event, "ProjectFunded", "Project was not funded again");
  assert.equal(event.args.projectIndex, 0, "Wrong project index");
  assert.equal(event.args.amount, 15, "Wrong funded amount");
  assert.equal(event.args.totalFunded.toNumber(), 25, "Total funding did not accumulate");
  assert.equal(event.args.currentMilestoneTotalFunded.toNumber(), 25, "Milestone funding did not accumulate");
});

//testuoja projekto pabaigima (+ keli milestones ivykdomi vienu metu + overshootinamas end goalas)
it("complete project by overshooting", async () => {
  transaction = await crowdSourcingContract.fundProject(0, {from: accounts[2], value: 200});

  const event = transaction.logs[0];

  assert.equal(event.event, "ProjectFunded", "Project was not funded again");
  assert.equal(event.args.projectIndex, 0, "Wrong project index");
  assert.equal(event.args.amount, 200, "Wrong funded amount");
  assert.equal(event.args.totalFunded.toNumber(), 200, "Total funding did not accumulate correctly (must be equals last milestone)");
  assert.equal(event.args.currentMilestoneTotalFunded.toNumber(), 200, "Milestones interpreted incorrectly (should be the funded amount up until this point)");
});

// //testuoja projekto stabdyma
// it("stop project", async () => {
//   await crowdSourcingContract.createProject("Testinis projektas2", "Nuotrauka.url", "Testavimas2", [[100, Math.floor(Date.now() / 1000) + 10000]], {from: accounts[1]});
//     transaction = crowdSourcingContract.stopProject({from: accounts[0]});
// });

});
