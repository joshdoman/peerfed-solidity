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

  describe("Exchange", function () {
    it("Should revert if invalid token address submitted", async function () {
      const { owner } = this.signers;

      await expect(
        this.orchestrator.exchangeShares(this.mToken.address, this.bShare.address, 100, 100, owner.address),
      ).to.be.revertedWith("StablecashOrchestrator: INVALID_TOKENS");

      await expect(
        this.orchestrator.exchangeShares(this.mShare.address, this.bToken.address, 100, 100, owner.address),
      ).to.be.revertedWith("StablecashOrchestrator: INVALID_TOKENS");
    });

    it("Should revert if no input or output amount is provided", async function () {
      const { owner } = this.signers;

      await expect(
        this.orchestrator.exchangeShares(this.mShare.address, this.bShare.address, 0, 0, owner.address),
      ).to.be.revertedWith("StablecashOrchestrator: MISSING_INPUT_OUTPUT");
    });

    it("Should update the scale factor to the exact value prior to the exchange", async function () {
      const { owner } = this.signers;

      const secondsToAdd = 100000;
      const interestRate = await this.orchestrator.interestRate();
      const secondsPerYear = await this.orchestrator.SECONDS_PER_YEAR();
      const currentScaleFactor = await this.orchestrator.scaleFactor();
      const exponent = interestRate.mul(secondsToAdd).div(secondsPerYear);
      const growthFactor = exp(exponent);
      const expectedScaleFactor = currentScaleFactor.mul(growthFactor).div(eth(1));
      // Add desired seconds - 1 (since calling updateScaleFactor will add one second)
      await addTime(secondsToAdd - 1);
      await this.orchestrator.exchangeShares(this.mShare.address, this.bShare.address, 100, 0, owner.address);
      expect(await this.orchestrator.scaleFactor()).to.equal(expectedScaleFactor);
      expect(await this.orchestrator.timeOfLastExchange()).to.equal(await getTime());
    });

    it("Should revert if invalid to", async function () {
      await expect(
        this.orchestrator.exchangeShares(this.mShare.address, this.bShare.address, 100, 0, this.mShare.address),
      ).to.be.revertedWith("StablecashOrchestrator: INVALID_TO");

      await expect(
        this.orchestrator.exchangeShares(this.mShare.address, this.bShare.address, 100, 0, this.bShare.address),
      ).to.be.revertedWith("StablecashOrchestrator: INVALID_TO");

      await expect(
        this.orchestrator.exchangeShares(this.mShare.address, this.bShare.address, 100, 0, this.orchestrator.address),
      ).to.be.revertedWith("StablecashOrchestrator: INVALID_TO");
    });

    it("Should revert if invalid exact exchange", async function () {
      const { owner } = this.signers;

      await expect(
        this.orchestrator.exchangeShares(this.mShare.address, this.bShare.address, 100, 100, owner.address),
      ).to.be.revertedWith("StablecashOrchestrator: INVALID_EXCHANGE");
    });

    it("Should revert if invalid output amount", async function () {
      const { owner } = this.signers;
      // Calculate max output supply using invariant and add 1
      const mShareSupply = await this.mShare.totalSupply();
      const bShareSupply = await this.bShare.totalSupply();
      const invariant = sumOfSquares(mShareSupply, bShareSupply);
      const invalidOutput = sqrt(invariant.div(eth(1))).add(1);
      await expect(
        this.orchestrator.exchangeShares(this.mShare.address, this.bShare.address, 0, invalidOutput, owner.address),
      ).to.be.revertedWith("StablecashOrchestrator: INVALID_EXCHANGE");
    });

    it("Should exchange exact amounts where new sum-of-squares is less than invariant", async function () {
      const { owner } = this.signers;

      const mShareBalance = await this.mShare.balanceOf(owner.address);
      const bShareBalance = await this.bShare.balanceOf(owner.address);
      await this.orchestrator.exchangeShares(this.mShare.address, this.bShare.address, 100, 50, owner.address);
      expect(await this.mShare.balanceOf(owner.address)).to.equal(mShareBalance.add(-100));
      expect(await this.bShare.balanceOf(owner.address)).to.equal(bShareBalance.add(50));
    });

    it("Should exchange exact amounts where new sum-of-squares equals invariant", async function () {
      const { owner } = this.signers;
      const inputAmount = 100;
      // Calculate invariant
      const mShareSupply = await this.mShare.totalSupply();
      const bShareSupply = await this.bShare.totalSupply();
      const invariant = sumOfSquares(mShareSupply, bShareSupply);
      // Calculate expected input and output supply
      const mShareBalance = await this.mShare.balanceOf(owner.address);
      const bShareBalance = await this.bShare.balanceOf(owner.address);
      const expectedInputSupply = mShareSupply.sub(inputAmount);
      const expectedOutputSupply = sqrt(invariant.sub(square(expectedInputSupply)).div(eth(1)));
      // Calculate expected input & output balance
      const expectedInputBalance = mShareBalance.add(-inputAmount);
      const desiredOutputAmount = expectedOutputSupply.sub(bShareSupply);
      const expectedOutputBalance = bShareBalance.add(desiredOutputAmount);
      // Execute exchange
      await this.orchestrator.exchangeShares(
        this.mShare.address,
        this.bShare.address,
        inputAmount,
        desiredOutputAmount,
        owner.address,
      );
      expect(await this.mShare.balanceOf(owner.address)).to.equal(expectedInputBalance);
      expect(await this.bShare.balanceOf(owner.address)).to.equal(expectedOutputBalance);
    });

    it("Should exchange correct amount when input amount provided", async function () {
      const { owner } = this.signers;
      // Calculate invariant
      const mShareSupply = await this.mShare.totalSupply();
      const bShareSupply = await this.bShare.totalSupply();
      const invariant = sumOfSquares(mShareSupply, bShareSupply);
      // Calculate expected input and output supply
      const mShareBalance = await this.mShare.balanceOf(owner.address);
      const bShareBalance = await this.bShare.balanceOf(owner.address);
      const expectedInputSupply = mShareSupply.sub(100);
      const expectedOutputSupply = sqrt(invariant.sub(square(expectedInputSupply)).div(eth(1)));
      // Calculate expected input & output balance
      const expectedInputBalance = mShareBalance.add(-100);
      const expectedOutputAmount = expectedOutputSupply.sub(bShareSupply);
      const expectedOutputBalance = bShareBalance.add(expectedOutputAmount);
      // Execute exchange
      await this.orchestrator.exchangeShares(this.mShare.address, this.bShare.address, 100, 0, owner.address);
      expect(await this.mShare.balanceOf(owner.address)).to.equal(expectedInputBalance);
      expect(await this.bShare.balanceOf(owner.address)).to.equal(expectedOutputBalance);
    });

    it("Should exchange correct amount when output amount provided", async function () {
      const { owner } = this.signers;
      // Calculate invariant
      const mShareSupply = await this.mShare.totalSupply();
      const bShareSupply = await this.bShare.totalSupply();
      const invariant = sumOfSquares(mShareSupply, bShareSupply);
      // Calculate expected input and output supply
      const mShareBalance = await this.mShare.balanceOf(owner.address);
      const bShareBalance = await this.bShare.balanceOf(owner.address);
      const expectedOutputSupply = mShareSupply.add(100);
      const expectedInputSupply = sqrt(invariant.sub(square(expectedOutputSupply)).div(eth(1)));
      // Calculate expected input and output balance
      const expectedInputAmount = bShareSupply.sub(expectedInputSupply);
      const expectedInputBalance = mShareBalance.sub(expectedInputAmount);
      const expectedOutputBalance = bShareBalance.add(100);
      // Execute exchange
      await this.orchestrator.exchangeShares(this.mShare.address, this.bShare.address, 0, 100, owner.address);
      expect(await this.mShare.balanceOf(owner.address)).to.equal(expectedInputBalance);
      expect(await this.bShare.balanceOf(owner.address)).to.equal(expectedOutputBalance);
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
