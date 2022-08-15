import { expect } from "chai";
import { BigNumber, utils } from "ethers";
import { ethers } from "hardhat";

export function shouldBehaveLikeUnmintedFlatcoin(): void {
  describe("Deployment", function () {
    it("Should set supply at zero at deployment", async function () {
      expect(await this.unmintedFlatcoin.totalSupply()).to.equal(0);
    });

    it("Should set the owner's balance at zero at deployment", async function () {
      const { owner } = this.signers;
      expect(await this.unmintedFlatcoin.balanceOf(owner.address)).to.equal(0);
    });
  });

  describe("Updating", function () {
    it("Should set the owner's balance correctly after time has passed", async function () {
      const { owner } = this.signers;
      const incomePerSecond = await this.flatcoinBond.incomePerSecond(owner.address);
      const startTime = await getTime();
      const timePassed = 31536000; // 1 year
      await setTime(startTime + timePassed);
      const expectedBalance = incomePerSecond.mul(BigNumber.from(timePassed)).div(eth(1));
      expect(await this.unmintedFlatcoin.balanceOf(owner.address)).to.equal(expectedBalance);
    });

    it("Should set supply correctly after time has passed", async function () {
      const totalIncomePerSecond = await this.flatcoinBond.totalIncomePerSecond();
      const startTime = await getTime();
      const timePassed = 31536000; // 1 year
      await setTime(startTime + timePassed);
      const expectedSupply = totalIncomePerSecond.mul(BigNumber.from(timePassed)).div(eth(1));
      expect(await this.unmintedFlatcoin.totalSupply()).to.equal(expectedSupply);
    });
  });

  describe("Minting", function () {
    it("Should mint the owner's unminted balance correctly", async function () {
      const { owner } = this.signers;
      const startTime = await getTime();
      await setTime((await getTime()) + 31536000); // Jump 1 year

      const flatcoinBalance = await this.flatcoin.balanceOf(owner.address);
      const incomePerSecond = await this.flatcoinBond.incomePerSecond(owner.address);

      await this.unmintedFlatcoin.mintFlatcoinsByOwner();

      const timeDelta = BigNumber.from((await getTime()) - startTime);
      const unmintedBalanceWhenMint = incomePerSecond.mul(timeDelta).div(eth(1));
      const expectedFlatcoinBalance = flatcoinBalance.add(unmintedBalanceWhenMint);
      expect(await this.flatcoin.balanceOf(owner.address)).to.equal(expectedFlatcoinBalance);
      // Unminted balance should be zero after minting
      expect(await this.unmintedFlatcoin.balanceOf(owner.address)).to.equal(0);
    });

    it("Should reduce the unminted supply by the mint amount", async function () {
      const { owner } = this.signers;
      await setTime((await getTime()) + 31536000); // Jump 1 year

      const unmintedSupply = await this.unmintedFlatcoin.totalSupply();
      const totalIncomePerSecond = await this.flatcoinBond.totalIncomePerSecond();
      const unmintedBalance = await this.unmintedFlatcoin.balanceOf(owner.address);
      const incomePerSecond = await this.flatcoinBond.incomePerSecond(owner.address);

      await this.unmintedFlatcoin.mintFlatcoinsByOwner();

      // Expected balance is flatcoin balance + unminted balance before minting
      // + incomePerSecond * 1 second (since minting adds one second)
      const mintAmount = unmintedBalance.add(incomePerSecond.div(eth(1)));

      // Unminted supply without mint is the unminted supply before mint +
      // totalIncomePerSecond * second (since minting adds one second)
      const unmintedSupplyWithoutMint = unmintedSupply.add(totalIncomePerSecond.div(eth(1)));

      const expectedUnmintedSupply = unmintedSupplyWithoutMint.sub(mintAmount);
      expect(await this.unmintedFlatcoin.totalSupply()).to.equal(expectedUnmintedSupply);
    });
  });
}

// ----- Helper Functions -----

export function eth(n: number) {
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
