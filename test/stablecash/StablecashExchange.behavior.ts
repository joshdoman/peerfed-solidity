import { exp, sqrt } from "@prb/math";
import { expect } from "chai";
import { BigNumber, utils } from "ethers";
import { ethers } from "hardhat";

export function shouldBehaveLikeStablecashExchange(): void {
  describe("Exchange", function () {
    it("Should revert if invalid token address submitted", async function () {
      const { owner } = this.signers;

      await expect(
        this.exchange.exchangeShares(this.mToken.address, this.bToken.address, 100, 100, owner.address),
      ).to.be.revertedWith("StablecashExchange: INVALID_TOKENS");

      await expect(
        this.exchange.exchangeShares(this.mToken.address, this.bShare.address, 100, 100, owner.address),
      ).to.be.revertedWith("StablecashExchange: INVALID_TOKENS");

      await expect(
        this.exchange.exchangeShares(this.mShare.address, this.bToken.address, 100, 100, owner.address),
      ).to.be.revertedWith("StablecashExchange: INVALID_TOKENS");
    });

    it("Should revert if no input or output amount is provided", async function () {
      const { owner } = this.signers;

      await expect(
        this.exchange.exchangeShares(this.mShare.address, this.bShare.address, 0, 0, owner.address),
      ).to.be.revertedWith("StablecashLibrary: INSUFFICIENT_OUTPUT_AMOUNT");
    });

    it("Should update the scale factor to the exact value prior to the exchange", async function () {
      const { owner } = this.signers;
      // Update the scale factor (to account for time accrued during initial auctions for the owner)
      await this.orchestrator.updateScaleFactor();
      // Add 100 seconcds and verify the new scale factor is updated
      const secondsToAdd = 100;
      const interestRate = await this.orchestrator.interestRate();
      const secondsPerYear = await this.orchestrator.SECONDS_PER_YEAR();
      const currentScaleFactor = await this.orchestrator.scaleFactor();
      const exponent = interestRate.mul(secondsToAdd).div(secondsPerYear);
      const growthFactor = exp(exponent);
      const expectedScaleFactor = currentScaleFactor.mul(growthFactor).div(eth(1));
      // Add desired seconds - 1 (since calling updateScaleFactor will add one second)
      await addTime(secondsToAdd - 1);
      await this.exchange.exchangeShares(this.mShare.address, this.bShare.address, 100, 0, owner.address);
      expect(await this.orchestrator.scaleFactor()).to.equal(expectedScaleFactor);
      expect(await this.orchestrator.timeOfLastExchange()).to.equal(await getTime());
    });

    it("Should revert if invalid to", async function () {
      await expect(
        this.exchange.exchangeShares(this.mShare.address, this.bShare.address, 100, 0, this.mShare.address),
      ).to.be.revertedWith("StablecashExchange: INVALID_TO");

      await expect(
        this.exchange.exchangeShares(this.mShare.address, this.bShare.address, 100, 0, this.bShare.address),
      ).to.be.revertedWith("StablecashExchange: INVALID_TO");
    });

    it("Should revert if invalid exact exchange", async function () {
      const { owner } = this.signers;

      await expect(
        this.exchange.exchangeShares(this.mShare.address, this.bShare.address, 100, 100, owner.address),
      ).to.be.revertedWith("StablecashExchange: INVALID_EXCHANGE");
    });

    it("Should revert if invalid output amount", async function () {
      const { owner } = this.signers;
      // Calculate max output supply using invariant and add 1
      const mShareSupply = await this.mShare.totalSupply();
      const bShareSupply = await this.bShare.totalSupply();
      const invariant = sumOfSquares(mShareSupply, bShareSupply);
      const invalidOutput = sqrt(invariant.div(eth(1))).add(1);
      await expect(
        this.exchange.exchangeShares(this.mShare.address, this.bShare.address, 0, invalidOutput, owner.address),
      ).to.be.revertedWith("StablecashLibrary: INSUFFICIENT_SUPPLY");
    });

    it("Should exchange exact amounts where new sum-of-squares is less than invariant", async function () {
      const { owner } = this.signers;

      const mShareBalance = await this.mShare.balanceOf(owner.address);
      const bShareBalance = await this.bShare.balanceOf(owner.address);
      await this.exchange.exchangeShares(this.mShare.address, this.bShare.address, 100, 50, owner.address);
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
      await this.exchange.exchangeShares(
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
      await this.exchange.exchangeShares(this.mShare.address, this.bShare.address, 100, 0, owner.address);
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
      await this.exchange.exchangeShares(this.mShare.address, this.bShare.address, 0, 100, owner.address);
      expect(await this.mShare.balanceOf(owner.address)).to.equal(expectedInputBalance);
      expect(await this.bShare.balanceOf(owner.address)).to.equal(expectedOutputBalance);
    });

    it("Should emit Exchange event", async function () {
      const { owner, addr1 } = this.signers;

      // Calculate invariant
      const mShareSupply = await this.mShare.totalSupply();
      const bShareSupply = await this.bShare.totalSupply();
      const invariant = sumOfSquares(mShareSupply, bShareSupply);
      // Calculate expected input and output supply
      const expectedOutputSupply = mShareSupply.add(100);
      const expectedInputSupply = sqrt(invariant.sub(square(expectedOutputSupply)).div(eth(1)));
      // Calculate expected input amount
      const expectedInputAmount = bShareSupply.sub(expectedInputSupply);

      // Exchange 100 tokens from owner to owner
      await expect(this.exchange.exchangeShares(this.mShare.address, this.bShare.address, 0, 100, addr1.address))
        .to.emit(this.exchange, "Exchange")
        .withArgs(this.mShare.address, this.bShare.address, expectedInputAmount, 100, owner.address, addr1.address);
    });
  });

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
      // Update the scale factor (to account for time accrued during initial auctions for the owner)
      await this.orchestrator.updateScaleFactor();
      // Add 100 seconds and get expected growth factor at that time
      const secondsToAdd = 100;
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
      // Update the scale factor (to account for time accrued during initial auctions for the owner)
      await this.orchestrator.updateScaleFactor();
      // Add 100 seconds and get expected growth factor at that time
      const secondsToAdd = 100;
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

export function sumOfSquares(q1: BigNumber, q2: BigNumber): BigNumber {
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
