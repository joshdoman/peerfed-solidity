import { time } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { BigNumber } from "ethers";
import { ethers } from "hardhat";

export function shouldBehaveLikePeerFed(): void {
  describe("Deploy", function () {
    it("Should set starting accumulator to 1 with 18 decimals", async function () {
      expect(await this.peerfed.accumulator()).to.equal(eth(1));
    });

    it("Should correctly initialize checkpoint array with length NUM_SAVED_CHECKPOINTS", async function () {
      const secondsPerCheckpoint = await this.peerfed.SECONDS_PER_CHECKPOINT();
      var checkpointTime = (await time.latest()) - secondsPerCheckpoint - 1;
      for (let i = 0; i < (await this.peerfed.NUM_SAVED_CHECKPOINTS()); i++) {
        const checkpoint = await this.peerfed.checkpoints(i);
        expect(checkpoint.accumulator).to.equal(eth(1));
        expect(checkpoint.interestRate).to.equal(eth(1));
        expect(checkpoint.blocktime).to.equal(checkpointTime);
      }
    });
  });

  describe("Bid and Mint", function () {
    it("Should allow bid if greater than current bid", async function () {
      const { owner } = this.signers;
      const bid = eth(0.001);
      await this.peerfed.bid({ value: bid });
      expect(await this.peerfed.currentBid()).to.equal(bid);
      expect(await this.peerfed.currentBidder()).to.equal(owner.address);
    });

    it("Should revert if bid is not greater than current bid", async function () {
      const bid = eth(0.001);
      await this.peerfed.bid({ value: bid });
      await expect(this.peerfed.bid({ value: bid })).to.be.revertedWith("PeerFed: INSUFFICIENT_BID");
    });

    it("Should mint to current bidder if bid has been made", async function () {
      const { owner, addr1 } = this.signers;
      const mintableAmount = await this.peerfed.mintableAmount();
      await this.peerfed.connect(addr1).bid({ value: eth(0.001) });
      await this.peerfed.connect(owner).mint();
      expect(await this.token0.balanceOf(addr1.address)).to.equal(mintableAmount.newToken0);
      expect(await this.token1.balanceOf(addr1.address)).to.equal(mintableAmount.newToken1);
    });

    it("Should mint to `msg.sender` if there is no bidder", async function () {
      const { owner } = this.signers;
      const mintableAmount = await this.peerfed.mintableAmount();
      await this.peerfed.mint();
      expect(await this.token0.balanceOf(owner.address)).to.equal(mintableAmount.newToken0);
      expect(await this.token1.balanceOf(owner.address)).to.equal(mintableAmount.newToken1);
    });

    it("Should mint to `msg.sender` if 35 minutes has elapsed since last checkpoint", async function () {
      const { owner, addr1 } = this.signers;
      const mintableAmount = await this.peerfed.mintableAmount();
      await this.peerfed.connect(addr1).bid({ value: eth(0.001) });
      const checkpoint = await this.peerfed.currentCheckpoint();
      const secondsUntilBidsExpire = await this.peerfed.SECONDS_UNTIL_BIDS_EXPIRE();
      await time.increaseTo(checkpoint.blocktime + secondsUntilBidsExpire + 1);
      await this.peerfed.connect(owner).mint();
      expect(await this.token0.balanceOf(owner.address)).to.equal(mintableAmount.newToken0);
      expect(await this.token1.balanceOf(owner.address)).to.equal(mintableAmount.newToken1);
    });

    it("Should revert if 30 minutes has not elapsed", async function () {
      await this.peerfed.mint();
      await expect(this.peerfed.mint()).to.be.revertedWith("PeerFed: MINT_UNAVAILABLE");
    });

    it("Should clear `currentBid` and `currentBidder` after mint", async function () {
      await this.peerfed.bid({ value: eth(0.001) });
      await this.peerfed.mint();
      expect(await this.peerfed.currentBid()).to.equal(0);
      expect(await this.peerfed.currentBidder()).to.equal(ethers.constants.AddressZero);
    });

    it("Should update reserves after mint", async function () {
      await this.peerfed.bid({ value: eth(0.001) });
      await this.peerfed.mint();
      const reserves = await this.peerfed.getReserves();
      expect(reserves._reserve0).to.equal(await this.token0.totalSupply());
      expect(reserves._reserve1).to.equal(await this.token1.totalSupply());
    });

    it("Should emit Mint event", async function () {
      const { owner } = this.signers;
      const mintableAmount = await this.peerfed.mintableAmount();
      expect(await this.peerfed.mint())
        .to.emit(this.peerfed, "Mint")
        .withArgs(owner.address, mintableAmount.newToken0, mintableAmount.newToken1);
    });
  });

  describe("Checkpoint", function () {
    it("Should increment checkpoint id on mint", async function () {
      const { owner } = this.signers;
      const checkpointID = await this.peerfed.currentCheckpointID();
      await this.peerfed.mint();
      expect(await this.peerfed.currentCheckpointID()).to.equal(checkpointID + 1)
    });
  });
}

export function eth(n: number) {
  return ethers.utils.parseEther(n.toString());
}
