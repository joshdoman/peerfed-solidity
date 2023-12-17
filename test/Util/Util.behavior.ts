import { time } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";

export function shouldBehaveLikeUtil(): void {
  describe("Deploy", function () {
    it("Should set starting accumulator to 1 with 18 decimals", async function () {
      expect(await this.util.accumulator()).to.equal(eth(1));
    });

    it("Should correctly initialize checkpoint array with length NUM_SAVED_CHECKPOINTS", async function () {
      const secondsPerCheckpoint = await this.util.SECONDS_PER_CHECKPOINT();
      const checkpointTime = (await time.latest()) - secondsPerCheckpoint - 1;
      for (let i = 0; i < (await this.util.NUM_SAVED_CHECKPOINTS()); i++) {
        const checkpoint = await this.util.checkpoints(i);
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
      await this.util.bid({ value: bid });
      expect(await this.util.currentBid()).to.equal(bid);
      expect(await this.util.currentBidder()).to.equal(owner.address);
    });

    it("Should revert if bid is not greater than current bid", async function () {
      const bid = eth(0.001);
      await this.util.bid({ value: bid });
      await expect(this.util.bid({ value: bid })).to.be.revertedWithCustomError(this.util, "InsufficientBid");
    });

    it("Should mint to current bidder if bid has been made", async function () {
      const { owner, addr1 } = this.signers;
      const mintableAmount = await this.util.mintableAmount();
      await this.util.connect(addr1).bid({ value: eth(0.001) });
      await this.util.connect(owner).mint();
      expect(await this.token0.balanceOf(addr1.address)).to.equal(mintableAmount.newToken0);
      expect(await this.token1.balanceOf(addr1.address)).to.equal(mintableAmount.newToken1);
    });

    it("Should mint to `msg.sender` if there is no bidder", async function () {
      const { owner } = this.signers;
      const mintableAmount = await this.util.mintableAmount();
      await this.util.mint();
      expect(await this.token0.balanceOf(owner.address)).to.equal(mintableAmount.newToken0);
      expect(await this.token1.balanceOf(owner.address)).to.equal(mintableAmount.newToken1);
    });

    it("Should mint to `msg.sender` if 35 minutes has elapsed since last checkpoint", async function () {
      const { owner, addr1 } = this.signers;
      const mintableAmount = await this.util.mintableAmount();
      await this.util.connect(addr1).bid({ value: eth(0.001) });
      const checkpoint = await this.util.currentCheckpoint();
      const secondsUntilBidsExpire = await this.util.SECONDS_UNTIL_BIDS_EXPIRE();
      await time.increaseTo(checkpoint.blocktime + secondsUntilBidsExpire + 1);
      await this.util.connect(owner).mint();
      expect(await this.token0.balanceOf(owner.address)).to.equal(mintableAmount.newToken0);
      expect(await this.token1.balanceOf(owner.address)).to.equal(mintableAmount.newToken1);
    });

    it("Should revert if 30 minutes has not elapsed", async function () {
      await this.util.mint();
      await expect(this.util.mint()).to.be.revertedWithCustomError(this.util, "MintUnavailable");
    });

    it("Should clear `currentBid` and `currentBidder` after mint", async function () {
      await this.util.bid({ value: eth(0.001) });
      await this.util.mint();
      expect(await this.util.currentBid()).to.equal(0);
      expect(await this.util.currentBidder()).to.equal(ethers.constants.AddressZero);
    });

    it("Should update reserves after mint", async function () {
      await this.util.bid({ value: eth(0.001) });
      await this.util.mint();
      const reserves = await this.util.getReserves();
      expect(reserves._reserve0).to.equal(await this.token0.totalSupply());
      expect(reserves._reserve1).to.equal(await this.token1.totalSupply());
    });

    it("Should emit Mint event", async function () {
      const { owner } = this.signers;
      const mintableAmount = await this.util.mintableAmount();
      await expect(this.util.mint())
        .to.emit(this.util, "Mint")
        .withArgs(owner.address, mintableAmount.newToken0, mintableAmount.newToken1);
    });
  });

  describe("Swap", function () {
    it("Should swap token0 for token1", async function () {
      const { owner, addr1 } = this.signers;
      await this.util.mint();
      const token0In = (await this.token0.balanceOf(owner.address)).div(10);
      await this.token0.transfer(this.util.address, token0In);
      const reserves = await this.util.getReserves();
      const token1Out = await this.library.getAmountOut(token0In, reserves._reserve0, reserves._reserve1);
      await this.util.swap(0, token1Out, addr1.address, []);
      await expect(await this.token1.balanceOf(addr1.address)).to.equal(token1Out);
    });

    it("Should swap token1 for token0", async function () {
      const { owner, addr1 } = this.signers;
      await this.util.mint();
      const token1In = (await this.token1.balanceOf(owner.address)).div(10);
      await this.token1.transfer(this.util.address, token1In);
      const reserves = await this.util.getReserves();
      const token0Out = await this.library.getAmountOut(token1In, reserves._reserve1, reserves._reserve0);
      await this.util.swap(token0Out, 0, addr1.address, []);
      await expect(await this.token0.balanceOf(addr1.address)).to.equal(token0Out);
    });

    it("Should revert if token0 swap exceeds invariant", async function () {
      const { owner, addr1 } = this.signers;
      await this.util.mint();
      const token0In = (await this.token0.balanceOf(owner.address)).div(10);
      await this.token0.transfer(this.util.address, token0In);
      const reserves = await this.util.getReserves();
      const token1Out = await this.library.getAmountOut(token0In, reserves._reserve0, reserves._reserve1);
      await expect(this.util.swap(0, token1Out.add(1), addr1.address, [])).to.be.revertedWithCustomError(
        this.util,
        "InvalidK",
      );
    });

    it("Should revert if token1 swap exceeds invariant", async function () {
      const { owner, addr1 } = this.signers;
      await this.util.mint();
      const token1In = (await this.token1.balanceOf(owner.address)).div(10);
      await this.token1.transfer(this.util.address, token1In);
      const reserves = await this.util.getReserves();
      const token0Out = await this.library.getAmountOut(token1In, reserves._reserve1, reserves._reserve0);
      await expect(this.util.swap(token0Out.add(1), 0, addr1.address, [])).to.be.revertedWithCustomError(
        this.util,
        "InvalidK",
      );
    });

    it("Should emit Swap event", async function () {
      const { owner, addr1 } = this.signers;
      await this.util.mint();
      const token1In = (await this.token1.balanceOf(owner.address)).div(10);
      await this.token1.transfer(this.util.address, token1In);
      const reserves = await this.util.getReserves();
      const token0Out = await this.library.getAmountOut(token1In, reserves._reserve1, reserves._reserve0);
      await expect(this.util.swap(token0Out, 0, addr1.address, []))
        .to.emit(this.util, "Swap")
        .withArgs(owner.address, 0, token1In, token0Out, 0, addr1.address);
    });

    it("Should update reserves on swap", async function () {
      const { owner, addr1 } = this.signers;
      await this.util.mint();
      const token1In = (await this.token1.balanceOf(owner.address)).div(10);
      await this.token1.transfer(this.util.address, token1In);
      const reserves = await this.util.getReserves();
      const token0Out = await this.library.getAmountOut(token1In, reserves._reserve1, reserves._reserve0);
      await this.util.swap(token0Out, 0, addr1.address, []);
      const newReserves = await this.util.getReserves();
      await expect(newReserves._reserve0).to.equal(await this.token0.totalSupply());
      await expect(newReserves._reserve1).to.equal(await this.token1.totalSupply());
      await expect(newReserves._blockTimestampLast).to.equal(await time.latest());
    });
  });

  describe("Checkpoint", function () {
    it("Should increment checkpoint id on mint", async function () {
      const checkpointID = await this.util.currentCheckpointID();
      await this.util.mint();
      expect(await this.util.currentCheckpointID()).to.equal(checkpointID + 1);
    });

    it("Should correctly update the average interest rate on mint", async function () {
      const { owner, addr1 } = this.signers;
      await this.util.mint();
      const token1In = (await this.token1.balanceOf(owner.address)).div(10);
      await this.token1.transfer(this.util.address, token1In);
      const reserves = await this.util.getReserves();
      const token0Out = await this.library.getAmountOut(token1In, reserves._reserve1, reserves._reserve0);
      await this.util.swap(token0Out, 0, addr1.address, []);

      const secondsPerCheckpoint = await this.util.SECONDS_PER_CHECKPOINT();
      await time.increase(secondsPerCheckpoint);
      await this.util.sync();

      const secondsPerYear = await this.util.SECONDS_PER_YEAR();
      const checkpointID = await this.util.currentCheckpointID();
      let accumulator = await this.util.accumulator();
      accumulator = accumulator.add(
        accumulator
          .mul(await this.util.interestRate())
          .div(eth(1))
          .div(secondsPerYear),
      );
      const nextCheckpoint = await this.util.checkpoints(checkpointID + 1);
      const checkpointTimeElapsed = (await time.latest()) - nextCheckpoint.blocktime + 1;
      const checkpointInterestRate = accumulator
        .sub(nextCheckpoint.accumulator)
        .mul(eth(1))
        .div(nextCheckpoint.accumulator)
        .mul(secondsPerYear)
        .div(checkpointTimeElapsed);
      await this.util.mint();

      const newCheckpoint = await this.util.currentCheckpoint();
      expect(newCheckpoint.interestRate).to.equal(checkpointInterestRate);
      expect(newCheckpoint.accumulator).to.equal(accumulator);
    });

    it("Should emit NewCheckpoint event on mint", async function () {
      const { owner, addr1 } = this.signers;
      await this.util.mint();
      const token1In = (await this.token1.balanceOf(owner.address)).div(10);
      await this.token1.transfer(this.util.address, token1In);
      const reserves = await this.util.getReserves();
      const token0Out = await this.library.getAmountOut(token1In, reserves._reserve1, reserves._reserve0);
      await this.util.swap(token0Out, 0, addr1.address, []);

      const secondsPerCheckpoint = await this.util.SECONDS_PER_CHECKPOINT();
      await time.increase(secondsPerCheckpoint);
      await this.util.sync();

      const secondsPerYear = await this.util.SECONDS_PER_YEAR();
      const checkpointID = await this.util.currentCheckpointID();
      let accumulator = await this.util.accumulator();
      accumulator = accumulator.add(
        accumulator
          .mul(await this.util.interestRate())
          .div(eth(1))
          .div(secondsPerYear),
      );
      const nextCheckpoint = await this.util.checkpoints(checkpointID + 1);
      const checkpointTimeElapsed = (await time.latest()) - nextCheckpoint.blocktime + 1;
      const checkpointInterestRate = accumulator
        .sub(nextCheckpoint.accumulator)
        .mul(eth(1))
        .div(nextCheckpoint.accumulator)
        .mul(secondsPerYear)
        .div(checkpointTimeElapsed);
      await expect(this.util.mint()).to.emit(this.util, "NewCheckpoint").withArgs(checkpointInterestRate, accumulator);
    });
  });
}

export function eth(n: number) {
  return ethers.utils.parseEther(n.toString());
}
