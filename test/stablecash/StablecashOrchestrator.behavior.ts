import { exp, sqrt } from "@prb/math";
import { expect } from "chai";
import { BigNumber, utils } from "ethers";
import { ethers } from "hardhat";

export function shouldBehaveLikeStablecashOrchestrator(): void {
  describe("Deployment", function () {
    it("Should assign the total supply of shares to the deployer", async function () {
      const { owner } = this.signers;

      const ownerMShareBalance = await this.mShare.balanceOf(owner.address);
      expect(await this.mShare.totalSupply()).to.equal(ownerMShareBalance);

      const ownerBShareBalance = await this.bShare.balanceOf(owner.address);
      expect(await this.bShare.totalSupply()).to.equal(ownerBShareBalance);
    });

    it("Should set the starting scale factor equal to one", async function () {
      expect(await this.orchestrator.scaleFactor()).to.equal(eth(1));
    });

    it("Should set the time of last exchange to now", async function () {
      expect(await this.orchestrator.timeOfLastExchange()).to.equal(await getTime());
    });
  });

  describe("Interest Rate", function () {
    it("Should correctly calculate the interest rate", async function () {
      const mShareSupply = await this.mShare.totalSupply();
      const bShareSupply = await this.bShare.totalSupply();
      const expectedInterestRate = mShareSupply.mul(eth(1)).div(bShareSupply);
      expect(await this.orchestrator.interestRate()).to.equal(expectedInterestRate);
    });

    it("Should update the interest rate after an exchange", async function () {
      // TODO: Implement
    });
  });

  describe("Scale Factor", function () {
    it("Scale factor should auto-update each second using a linear approximation", async function () {
      const secondsToAdd = 100;
      const interestRate = await this.orchestrator.interestRate();
      const secondsPerYear = await this.orchestrator.SECONDS_PER_YEAR();
      const currentScaleFactor = await this.orchestrator.scaleFactor();
      const expectedScaleFactor = currentScaleFactor.add(interestRate.mul(secondsToAdd).div(secondsPerYear));
      await addTime(secondsToAdd);
      expect(await this.orchestrator.scaleFactor()).to.equal(expectedScaleFactor);
    });

    it("Should update the scale factor exactly using continuous compounding", async function () {
      const secondsToAdd = 100000;
      const interestRate = await this.orchestrator.interestRate();
      const secondsPerYear = await this.orchestrator.SECONDS_PER_YEAR();
      const currentScaleFactor = await this.orchestrator.scaleFactor();
      const exponent = interestRate.mul(secondsToAdd).div(secondsPerYear);
      const growthFactor = exp(exponent);
      const expectedScaleFactor = currentScaleFactor.mul(growthFactor).div(eth(1));
      // Add desired seconds - 1 (since calling updateScaleFactor will add one second)
      await addTime(secondsToAdd - 1);
      await this.orchestrator.updateScaleFactor();
      expect(await this.orchestrator.scaleFactor()).to.equal(expectedScaleFactor);
    });

    it("Should update the time of last exchange after updating the scale factor exactly", async function () {
      await addTime(100000);
      await this.orchestrator.updateScaleFactor();
      expect(await this.orchestrator.timeOfLastExchange()).to.equal(await getTime());
    });
  });
}

function sumOfSquares(q1: BigNumber, q2: BigNumber): BigNumber {
  return square(q1).add(square(q2));
}

function square(q: BigNumber): BigNumber {
  return q.mul(q);
}

function eth(n: number) {
  return utils.parseEther(n.toString());
}

export async function getTime(): Promise<number> {
  const blockNumBefore = await ethers.provider.getBlockNumber();
  const blockBefore = await ethers.provider.getBlock(blockNumBefore);
  return blockBefore.timestamp;
}

export async function setTime(newTime: number): Promise<void> {
  await ethers.provider.send("evm_mine", [newTime]);
}

export async function addTime(seconds: number): Promise<void> {
  const time = await getTime();
  await setTime(time + seconds);
}
