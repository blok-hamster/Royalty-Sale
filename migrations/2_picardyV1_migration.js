const PicardyV1 = artifacts.require("PicardyV1");

module.exports = async function (deployer, network, accounts) {
  await deployer.deploy(PicardyV1);
  let picardy = await PicardyV1.deployed();

  await picardy.join("F3mi", {from: accounts[8]});
  await picardy.createRoyaltySale(10, 5, 1, 70, "Love and Light", "LAL", "", "F3mi", {from: accounts[8]});
  await picardy.buyRoyalty("F3mi", "Love and Light", 5, {value: (5)});
  
  
  let royaltyAdress = await picardy.getRoyaltyAdress("F3mi", "Love and Light");
  console.log("royaltyAdress :" + royaltyAdress);
  
  
  let walletOfOwner = await picardy.getOwnerRoyaltyNft("F3mi", "Love and Light"); 
  
  
  console.log(walletOfOwner);
  await picardy.buyRoyalty("F3mi", "Love and Light", 5, {value: (5), from: accounts[4]});

  
  await picardy.createTicket(20, 5, 1, "Love and Light Concert", "LALC", "", "F3mi", {from: accounts[8]});
  await picardy.buyTicket("F3mi", "Love and Light Concert", 5, {value: (5)});

  //await picardy.updateRoyaltyBalance("F3mi", "Love and Light", 200);
  //await picardy.claimRoyalty("F3mi", "Love and Light", {from: accounts[2]});
  
};
