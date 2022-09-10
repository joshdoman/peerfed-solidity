import { exp, sqrt } from "@prb/math";
import { expect } from "chai";
import { BigNumber, utils } from "ethers";
import { ethers } from "hardhat";

export function shouldBehaveLikeStablecashExchange(): void {
  describe("Deadline", function () {
    it("Should revert if deadline has expired", async function () {
      const { owner } = this.signers;

      const address1 = this.mShare.address;
      const address2 = this.bShare.address;
      const address3 = this.mToken.address;
      const address4 = this.bToken.address;
      const deadline = (await getTime()) - 1;
      await expect(
        this.exchange.exchangeExactSharesForShares(address1, address2, 100, 100, owner.address, deadline),
      ).to.be.revertedWith("StablecashExchange: EXPIRED");

      await expect(
        this.exchange.exchangeSharesForExactShares(address1, address2, 100, 100, owner.address, deadline),
      ).to.be.revertedWith("StablecashExchange: EXPIRED");

      await expect(
        this.exchange.exchangeExactTokensForTokens(address3, address4, 100, 100, owner.address, deadline),
      ).to.be.revertedWith("StablecashExchange: EXPIRED");

      await expect(
        this.exchange.exchangeTokensForExactTokens(address3, address4, 100, 100, owner.address, deadline),
      ).to.be.revertedWith("StablecashExchange: EXPIRED");
    });
  });

  describe("Exact Share Exchange", function () {
    it("Should revert if invalid token address submitted", async function () {
      const { owner } = this.signers;
      const address1 = this.mShare.address;
      const address2 = this.bShare.address;
      const address3 = this.mToken.address;
      const address4 = this.bToken.address;
      const deadline = (await getTime()) + 100;
      await expect(
        this.exchange.exchangeExactSharesForShares(address3, address2, 100, 100, owner.address, deadline),
      ).to.be.revertedWith("StablecashOrchestrator: INVALID_TOKENS");

      await expect(
        this.exchange.exchangeExactSharesForShares(address1, address4, 100, 100, owner.address, deadline),
      ).to.be.revertedWith("StablecashOrchestrator: INVALID_TOKENS");
    });

    it("Should exchange when minimum output satisfied", async function () {
      const { owner } = this.signers;
      const address1 = this.mShare.address;
      const address2 = this.bShare.address;
      const deadline = (await getTime()) + 100;
      const ownerMBalance = await this.mShare.balanceOf(owner.address);
      const ownerBBalance = await this.bShare.balanceOf(owner.address);
      const expectedMBalance = ownerMBalance.sub(100);
      const minExpectedBBalance = ownerBBalance.add(50);
      await this.exchange.exchangeExactSharesForShares(address1, address2, 100, 50, owner.address, deadline);
      expect(await this.mShare.balanceOf(owner.address)).to.equal(expectedMBalance);
      expect(await this.bShare.balanceOf(owner.address)).to.be.above(minExpectedBBalance);
    });

    it("Should fail when minimum output not satisfied", async function () {
      const { owner } = this.signers;
      const address1 = this.mShare.address;
      const address2 = this.bShare.address;
      const deadline = (await getTime()) + 100;
      await expect(
        this.exchange.exchangeExactSharesForShares(address1, address2, 100, 150, owner.address, deadline),
      ).to.be.revertedWith("StablecashExchange: INSUFFICIENT_OUTPUT_AMOUNT");
    });

    it("Should exchange when maximum input satisfied", async function () {
      const { owner } = this.signers;
      const address1 = this.mShare.address;
      const address2 = this.bShare.address;
      const deadline = (await getTime()) + 100;
      const ownerMBalance = await this.mShare.balanceOf(owner.address);
      const ownerBBalance = await this.bShare.balanceOf(owner.address);
      const minExpectedMBalance = ownerMBalance.sub(150);
      const expectedBBalance = ownerBBalance.add(100);
      await this.exchange.exchangeSharesForExactShares(address1, address2, 100, 150, owner.address, deadline);
      expect(await this.mShare.balanceOf(owner.address)).to.be.above(minExpectedMBalance);
      expect(await this.bShare.balanceOf(owner.address)).to.equal(expectedBBalance);
    });

    it("Should fail when maximum input not satisfied", async function () {
      const { owner } = this.signers;
      const address1 = this.mShare.address;
      const address2 = this.bShare.address;
      const deadline = (await getTime()) + 100;
      await expect(
        this.exchange.exchangeSharesForExactShares(address1, address2, 100, 50, owner.address, deadline),
      ).to.be.revertedWith("StablecashExchange: EXCESSIVE_INPUT_AMOUNT");
    });
  });

  describe("Exact Token Exchange", function () {
    it("Should exchange when minimum output satisfied", async function () {
      const secondsToAdd = 100000;
      const interestRate = await this.orchestrator.interestRate();
      const secondsPerYear = await this.orchestrator.SECONDS_PER_YEAR();
      const currentScaleFactor = await this.orchestrator.scaleFactor();
      const exponent = interestRate.mul(secondsToAdd).div(secondsPerYear);
      const growthFactor = exp(exponent);
      const expectedScaleFactor = currentScaleFactor.mul(growthFactor).div(eth(1));
      // Add desired seconds - 1 (since calling exchange function will add one second)
      await addTime(secondsToAdd - 1);

      const { owner } = this.signers;
      const address1 = this.mToken.address;
      const address2 = this.bToken.address;
      const deadline = (await getTime()) + 100;
      const ownerMShareBalance = await this.mShare.balanceOf(owner.address);
      const ownerBBalance = await this.bToken.balanceOf(owner.address);
      const shareAmountIn = eth(100).div(expectedScaleFactor);
      const expectedMShareBalance = ownerMShareBalance.sub(shareAmountIn);
      const expectedMBalance = expectedMShareBalance.mul(expectedScaleFactor).div(eth(1));
      const minExpectedBBalance = ownerBBalance.add(50);
      await this.exchange.exchangeExactTokensForTokens(address1, address2, 100, 50, owner.address, deadline);
      expect(await this.mToken.balanceOf(owner.address)).to.equal(expectedMBalance);
      expect(await this.bToken.balanceOf(owner.address)).to.be.above(minExpectedBBalance);
    });

    it("Should fail when minimum output not satisfied", async function () {
      const { owner } = this.signers;
      const address1 = this.mToken.address;
      const address2 = this.bToken.address;
      const deadline = (await getTime()) + 100;
      await expect(
        this.exchange.exchangeExactTokensForTokens(address1, address2, 100, 150, owner.address, deadline),
      ).to.be.revertedWith("StablecashExchange: INSUFFICIENT_OUTPUT_AMOUNT");
    });

    it("Should exchange when maximum input satisfied", async function () {
      const secondsToAdd = 100000;
      const interestRate = await this.orchestrator.interestRate();
      const secondsPerYear = await this.orchestrator.SECONDS_PER_YEAR();
      const currentScaleFactor = await this.orchestrator.scaleFactor();
      const exponent = interestRate.mul(secondsToAdd).div(secondsPerYear);
      const growthFactor = exp(exponent);
      const expectedScaleFactor = currentScaleFactor.mul(growthFactor).div(eth(1));
      // Add desired seconds - 1 (since calling exchange function will add one second)
      await addTime(secondsToAdd - 1);

      const { owner } = this.signers;
      const address1 = this.mToken.address;
      const address2 = this.bToken.address;
      const deadline = (await getTime()) + 100;
      const ownerMBalance = await this.mToken.balanceOf(owner.address);
      const ownerBShareBalance = await this.bShare.balanceOf(owner.address);
      const shareAmountOut = eth(100).div(expectedScaleFactor);
      const expectedBShareBalance = ownerBShareBalance.add(shareAmountOut);
      const expectedBBalance = expectedBShareBalance.mul(expectedScaleFactor).div(eth(1));
      const minExpectedMBalance = ownerMBalance.sub(150);
      await this.exchange.exchangeTokensForExactTokens(address1, address2, 100, 150, owner.address, deadline);
      expect(await this.mToken.balanceOf(owner.address)).to.be.above(minExpectedMBalance);
      expect(await this.bToken.balanceOf(owner.address)).to.equal(expectedBBalance);
    });

    it("Should fail when maximum input not satisfied", async function () {
      const { owner } = this.signers;
      const address1 = this.mToken.address;
      const address2 = this.bToken.address;
      const deadline = (await getTime()) + 100;
      await expect(
        this.exchange.exchangeTokensForExactTokens(address1, address2, 100, 50, owner.address, deadline),
      ).to.be.revertedWith("StablecashExchange: EXCESSIVE_INPUT_AMOUNT");
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
