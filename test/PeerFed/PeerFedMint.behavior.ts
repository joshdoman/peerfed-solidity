import { sqrt } from "@prb/math";
import { expect } from "chai";
import { utils } from "ethers";

import { sumOfSquares } from "./PeerFedConverter.behavior";

export function shouldBehaveLikePeerFedMint(): void {
  describe("Mint", function () {
    it("Should correctly calculate the mintable amount", async function () {
      // Calculate invariant prior to settling the auction
      const mShareSupply = await this.mShare.totalSupply();
      const bShareSupply = await this.bShare.totalSupply();
      const invariant = sqrt(sumOfSquares(mShareSupply, bShareSupply).div(eth(1)));
      // Calculate the amount of mShares and bShares to mint
      const issuance = await this.orchestrator.getInvariantIssuance(await this.orchestrator.mintNumber());
      const expectedMShares = mShareSupply.mul(issuance).div(invariant);
      const expectedBShares = bShareSupply.mul(issuance).div(invariant);
      // Calculate the amount of mTokens and bTokens to mint
      const scaleFactor = await this.orchestrator.scaleFactor();
      const expectedMTokens = expectedMShares.mul(scaleFactor).div(eth(1));
      const expectedBTokens = expectedBShares.mul(scaleFactor).div(eth(1));
      // Get available mintable amount
      const { mShares, bShares, mTokens, bTokens } = await this.orchestrator.mintableAmount();
      // Check mintable amount matches expected amount
      expect(mShares).to.equal(expectedMShares);
      expect(bShares).to.equal(expectedBShares);
      expect(mTokens).to.equal(expectedMTokens);
      expect(bTokens).to.equal(expectedBTokens);
    });

    it("Should mint the mintable amount to the msg sender", async function () {
      const { owner } = this.signers;
      // Get the owner's share balance prior to minting
      const mShareBalance = await this.mShare.balanceOf(owner.address);
      const bShareBalance = await this.bShare.balanceOf(owner.address);
      // Get available mintable amount
      const { mShares, bShares } = await this.orchestrator.mintableAmount();
      // Mint to owner
      await this.orchestrator.mint();
      // Check if the owner's balance increased by expected amount
      expect(await this.mShare.balanceOf(owner.address)).to.equal(mShareBalance.add(mShares));
      expect(await this.bShare.balanceOf(owner.address)).to.equal(bShareBalance.add(bShares));
    });

    it("Should mint the mintable amount to the designated address", async function () {
      const { addr1 } = this.signers;
      // Get the owner's share balance prior to minting
      const mShareBalance = await this.mShare.balanceOf(addr1.address);
      const bShareBalance = await this.bShare.balanceOf(addr1.address);
      // Get available mintable amount
      const { mShares, bShares } = await this.orchestrator.mintableAmount();
      // Mint to owner
      await this.orchestrator.mintTo(addr1.address);
      // Check if the owner's balance increased by expected amount
      expect(await this.mShare.balanceOf(addr1.address)).to.equal(mShareBalance.add(mShares));
      expect(await this.bShare.balanceOf(addr1.address)).to.equal(bShareBalance.add(bShares));
    });

    it("Should increment mint number", async function () {
      const mintNumber = await this.orchestrator.mintNumber();
      // Mint to owner
      await this.orchestrator.mint();
      // Get updated mint number and check that it's correct
      const newMintNumber = await this.orchestrator.mintNumber();
      expect(newMintNumber).to.equal(mintNumber.add(1));
    });

    it("Should correctly calculate the invariant issuance amount", async function () {
      const INITIAL_ISSUANCE_PER_MINT = await this.orchestrator.INITIAL_ISSUANCE_PER_MINT();
      const MINTS_PER_HALVING = await this.orchestrator.MINTS_PER_HALVING();
      expect(await this.orchestrator.getInvariantIssuance(1)).equal(INITIAL_ISSUANCE_PER_MINT);
      expect(await this.orchestrator.getInvariantIssuance(MINTS_PER_HALVING.sub(1))).equal(INITIAL_ISSUANCE_PER_MINT);
      expect(await this.orchestrator.getInvariantIssuance(MINTS_PER_HALVING)).equal(INITIAL_ISSUANCE_PER_MINT.div(2));
      expect(await this.orchestrator.getInvariantIssuance(MINTS_PER_HALVING.mul(2).sub(1))).equal(
        INITIAL_ISSUANCE_PER_MINT.div(2),
      );
      expect(await this.orchestrator.getInvariantIssuance(MINTS_PER_HALVING.mul(2))).equal(
        INITIAL_ISSUANCE_PER_MINT.div(4),
      );
    });

    it("Should increase invariant by issuance amount", async function () {
      // Calculate invariant prior to minting
      const mShareSupply = await this.mShare.totalSupply();
      const bShareSupply = await this.bShare.totalSupply();
      const invariant = sqrt(sumOfSquares(mShareSupply, bShareSupply));
      // Get amount of invariant issuance for the next mint
      const issuance = await this.orchestrator.getInvariantIssuance(await this.orchestrator.mintNumber());
      // Mint to owner
      await this.orchestrator.mint();
      // Calculate invariant after minting
      const newMShareSupply = await this.mShare.totalSupply();
      const newBShareSupply = await this.bShare.totalSupply();
      const newInvariant = sqrt(sumOfSquares(newMShareSupply, newBShareSupply));
      // Spread between invariant plus issuance and new invariant should be less than 0.001e18
      expect(invariant.add(issuance).sub(newInvariant)).to.be.at.most(eth(0.001));
    });

    it("Should not change the interest rate", async function () {
      // Get the interest rate prior to minting
      const interestRate = await this.orchestrator.interestRate();
      // Mint to owner
      await this.orchestrator.mint();
      // Compare the new interest rate
      const newInterestRate = await this.orchestrator.interestRate();
      if (newInterestRate.gt(interestRate)) {
        expect(newInterestRate.sub(interestRate)).to.be.at.most(eth(0.00001));
      } else {
        expect(interestRate.sub(newInterestRate)).to.be.at.most(eth(0.00001));
      }
      expect(newInterestRate).to.equal(interestRate);
    });

    it("Should emit Mint event", async function () {
      const { owner } = this.signers;
      // Get available mintable amount
      const { mShares, bShares } = await this.orchestrator.mintableAmount();
      // Verify the Mint event is emitted correctly
      const mintNumber = await this.orchestrator.mintNumber();
      await expect(await this.orchestrator.mint())
        .to.emit(this.orchestrator, "Mint")
        .withArgs(mintNumber, owner.address, mShares, bShares);
    });
  });
}

function eth(n: number) {
  return utils.parseEther(n.toString());
}
