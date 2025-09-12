import { expect } from "chai";
import { ethers } from "hardhat";

describe("Clave", function () {
  it("Test contract", async function () {
    const ContractFactory = await ethers.getContractFactory("Clave");

    const defaultAdmin = (await ethers.getSigners())[0].address;
    const minter = (await ethers.getSigners())[1].address;

    const instance = await ContractFactory.deploy(defaultAdmin, minter);
    await instance.waitForDeployment();

    expect(await instance.name()).to.equal("Clave");
  });
});
