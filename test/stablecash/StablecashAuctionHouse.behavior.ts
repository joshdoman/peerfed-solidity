import { sqrt } from "@prb/math";
import { expect } from "chai";
import { constants, utils } from "ethers";
import { ethers } from "hardhat";

import { sumOfSquares } from "./StablecashExchange.behavior";

export function shouldBehaveLikeStablecashAuctionHouse(): void {
  describe("Deployment", function () {
    it("Should assign the total initial supply of shares to the auction house", async function () {
      const auctionMShareBalance = await this.mShare.balanceOf(this.auctionHouse.address);
      expect(await this.mShare.totalSupply()).to.equal(auctionMShareBalance);

      const auctionBShareBalance = await this.bShare.balanceOf(this.auctionHouse.address);
      expect(await this.bShare.totalSupply()).to.equal(auctionBShareBalance);
    });

    it("Should create the first auction", async function () {
      const auction = await this.auctionHouse.auction();
      expect(auction["startTime"]).to.equal(await getTime());
      expect(auction["bidAmount"]).to.equal(0);
      expect(auction["bidder"]).to.equal(constants.AddressZero);
      expect(auction["number"]).to.equal(0);
    });
  });

  describe("Bid", function () {
    it("Should revert if auction has ended", async function () {
      const auction = await this.auctionHouse.auction();
      const DURATION = await this.auctionHouse.DURATION();
      const endTime = auction["startTime"].add(DURATION);
      // End the auction
      await setTime(endTime.toNumber() + 1);
      await expect(this.auctionHouse.bid()).to.be.revertedWith("StablecashAuctionHouse: AUCTION_ENDED");
    });

    it("Should accept bid if no prior bids", async function () {
      const { owner } = this.signers;
      await this.auctionHouse.bid({ value: eth(1) }); // Bid 1 ETH
      const updatedAuction = await this.auctionHouse.auction();
      const bidAmount = updatedAuction["bidAmount"];
      const bidder = updatedAuction["bidder"];
      expect(bidAmount).to.equal(eth(1));
      expect(bidder).to.equal(owner.address);
    });

    it("Should accept bid if greater than or equal to prior bid plus minimum bid increment", async function () {
      const { addr1 } = this.signers;
      const priorBid = eth(1);
      await this.auctionHouse.bid({ value: priorBid }); // Bid 1 ETH
      // Create second bid that is greater than previous bid but less than minimum bid increment
      const MIN_BID_INCREMENT_PERCENTAGE = await this.auctionHouse.MIN_BID_INCREMENT_PERCENTAGE();
      const secondBid = priorBid.add(priorBid.mul(MIN_BID_INCREMENT_PERCENTAGE).div(100));
      // Bid second amount
      await this.auctionHouse.connect(addr1).bid({ value: secondBid });
      // Verify bid amount and bidder is updated
      const updatedAuction = await this.auctionHouse.auction();
      const bidAmount = updatedAuction["bidAmount"];
      const bidder = updatedAuction["bidder"];
      expect(bidAmount).to.equal(secondBid);
      expect(bidder).to.equal(addr1.address);
    });

    it("Should refund the prior bidder if bid is accepted", async function () {
      const { owner, addr1 } = this.signers;
      await this.auctionHouse.bid({ value: eth(1) }); // Bid 1 ETH
      await expect(
        this.auctionHouse.connect(addr1).bid({ value: eth(2) }), // Bid 2 ETH
      ).to.changeEtherBalance(owner, eth(1));
    });

    it("Should revert if bid amount is less than previous bid", async function () {
      await this.auctionHouse.bid({ value: eth(1) }); // Bid 1 ETH
      await expect(
        this.auctionHouse.bid({ value: eth(0.5) }), // Bid 0.5 ETH
      ).to.be.revertedWith("StablecashAuctionHouse: INSUFFICIENT_BID");
    });

    it("Should revert if bid amount is equals previous bid", async function () {
      await this.auctionHouse.bid({ value: eth(1) }); // Bid 1 ETH
      await expect(
        this.auctionHouse.bid({ value: eth(1) }), // Bid 1 ETH
      ).to.be.revertedWith("StablecashAuctionHouse: INSUFFICIENT_BID");
    });

    it("Should revert if bid amount is less that minimum bid increment over prior bid", async function () {
      const priorBid = eth(1);
      await this.auctionHouse.bid({ value: priorBid }); // Bid 1 ETH
      // Create second bid that is greater than previous bid but less than minimum bid increment
      const MIN_BID_INCREMENT_PERCENTAGE = await this.auctionHouse.MIN_BID_INCREMENT_PERCENTAGE();
      const secondBid = priorBid.add(priorBid.mul(MIN_BID_INCREMENT_PERCENTAGE).div(100).div(2));
      await expect(
        this.auctionHouse.bid({ value: secondBid }), // Bid 1.005 ETH
      ).to.be.revertedWith("StablecashAuctionHouse: INSUFFICIENT_BID");
    });

    it("Should emit AuctionBid event", async function () {
      const { owner } = this.signers;
      const auction = await this.auctionHouse.auction();
      const bidAmount = eth(1);
      await expect(await this.auctionHouse.bid({ value: bidAmount }))
        .to.emit(this.auctionHouse, "AuctionBid")
        .withArgs(auction["number"], owner.address, bidAmount);
    });
  });

  describe("Settle", function () {
    it("Should revert if auction has not ended", async function () {
      const auction = await this.auctionHouse.auction();
      const DURATION = await this.auctionHouse.DURATION();
      const endTime = auction["startTime"].add(DURATION);
      // Set time just prior to auction ending (calling function will add one second, do decrement 2)
      await setTime(endTime.toNumber() - 2);
      await expect(this.auctionHouse.settleCurrentAndCreateNewAuction()).to.be.revertedWith(
        "StablecashAuctionHouse: AUCTION_HAS_NOT_ENDED",
      );
    });

    it("Should mint the auction house balance to the winning bidder", async function () {
      const { owner } = this.signers;

      const auction = await this.auctionHouse.auction();
      const DURATION = await this.auctionHouse.DURATION();
      const endTime = auction["startTime"].add(DURATION);
      // Bid 1 ETH
      await this.auctionHouse.bid({ value: eth(1) });
      // End the auction
      await setTime(endTime.toNumber());
      // Get the auction house's share balance prior to settling the auction
      const mAmount = await this.mShare.balanceOf(this.auctionHouse.address);
      const bAmount = await this.bShare.balanceOf(this.auctionHouse.address);
      // Get the owner's share balance prior to settling the auction
      const mShareBalance = await this.mShare.balanceOf(owner.address);
      const bShareBalance = await this.bShare.balanceOf(owner.address);
      // Settle the auction
      await this.auctionHouse.settleCurrentAndCreateNewAuction();
      // Check if the owner's balance increased by expected amount
      expect(await this.mShare.balanceOf(owner.address)).to.equal(mShareBalance.add(mAmount));
      expect(await this.bShare.balanceOf(owner.address)).to.equal(bShareBalance.add(bAmount));
    });

    it("Should emit AuctionSettled event", async function () {
      const { owner } = this.signers;
      const auction = await this.auctionHouse.auction();
      const DURATION = await this.auctionHouse.DURATION();
      const endTime = auction["startTime"].add(DURATION);
      // Bid 1 ETH
      await this.auctionHouse.bid({ value: eth(1) });
      // End the auction
      await setTime(endTime.toNumber());
      // Get the auction house's share balance prior to settling the auction
      const mAmount = await this.mShare.balanceOf(this.auctionHouse.address);
      const bAmount = await this.bShare.balanceOf(this.auctionHouse.address);
      // Verify the AuctionSettled event is emitted correctly
      await expect(await this.auctionHouse.settleCurrentAndCreateNewAuction())
        .to.emit(this.auctionHouse, "AuctionSettled")
        .withArgs(auction["number"], mAmount, bAmount, owner.address, eth(1));
    });
  });

  describe("Create New", function () {
    it("Should increment auction number", async function () {
      const auction = await this.auctionHouse.auction();
      const DURATION = await this.auctionHouse.DURATION();
      const endTime = auction["startTime"].add(DURATION);
      // End the auction
      await setTime(endTime.toNumber());
      // Settle and create new auction
      await this.auctionHouse.settleCurrentAndCreateNewAuction();
      // Get updated auction number and verify that it's correct
      const newAuction = await this.auctionHouse.auction();
      expect(newAuction["number"]).to.equal(auction["number"].add(1));
    });

    it("Should reset bidder and bid amount", async function () {
      const auction = await this.auctionHouse.auction();
      const DURATION = await this.auctionHouse.DURATION();
      const endTime = auction["startTime"].add(DURATION);
      // End the auction
      await setTime(endTime.toNumber());
      // Settle and create new auction
      await this.auctionHouse.settleCurrentAndCreateNewAuction();
      // Get updated auction and verify that bidder and bid amount is correct
      const newAuction = await this.auctionHouse.auction();
      expect(newAuction["bidder"]).to.equal(constants.AddressZero);
      expect(newAuction["bidAmount"]).to.equal(0);
    });

    it("Should set start time to current time", async function () {
      const auction = await this.auctionHouse.auction();
      const DURATION = await this.auctionHouse.DURATION();
      const endTime = auction["startTime"].add(DURATION);
      // End the auction
      await setTime(endTime.toNumber());
      // Settle and create new auction
      await this.auctionHouse.settleCurrentAndCreateNewAuction();
      // Get updated auction and verify that the start time is the current time
      const newAuction = await this.auctionHouse.auction();
      expect(newAuction["startTime"]).to.equal(await getTime());
    });

    it("Should correctly calculate the invariant issuance amount", async function () {
      const INITIAL_ISSUANCE = await this.auctionHouse.INITIAL_ISSUANCE();
      const AUCTIONS_PER_HALVING = await this.auctionHouse.AUCTIONS_PER_HALVING();
      expect(await this.auctionHouse.getInvariantIssuance(1)).equal(INITIAL_ISSUANCE);
      expect(await this.auctionHouse.getInvariantIssuance(AUCTIONS_PER_HALVING.sub(1))).equal(INITIAL_ISSUANCE);
      expect(await this.auctionHouse.getInvariantIssuance(AUCTIONS_PER_HALVING)).equal(INITIAL_ISSUANCE.div(2));
      expect(await this.auctionHouse.getInvariantIssuance(AUCTIONS_PER_HALVING.mul(2).sub(1))).equal(
        INITIAL_ISSUANCE.div(2),
      );
      expect(await this.auctionHouse.getInvariantIssuance(AUCTIONS_PER_HALVING.mul(2))).equal(INITIAL_ISSUANCE.div(4));
    });

    it("Should increase invariant by issuance amount", async function () {
      const auction = await this.auctionHouse.auction();
      const DURATION = await this.auctionHouse.DURATION();
      const endTime = auction["startTime"].add(DURATION);
      // Bid 1 ETH
      await this.auctionHouse.bid({ value: eth(1) });
      // End the auction
      await setTime(endTime.toNumber());
      // Calculate invariant prior to settling the auction
      const mShareSupply = await this.mShare.totalSupply();
      const bShareSupply = await this.bShare.totalSupply();
      const invariant = sqrt(sumOfSquares(mShareSupply, bShareSupply));
      // Settle the auction
      await this.auctionHouse.settleCurrentAndCreateNewAuction();
      // Calculate invariant after settling the auction
      const newMShareSupply = await this.mShare.totalSupply();
      const newBShareSupply = await this.bShare.totalSupply();
      const newInvariant = sqrt(sumOfSquares(newMShareSupply, newBShareSupply));
      // Get amount of invariant issuance for the new auction
      const issuance = await this.auctionHouse.getInvariantIssuance(auction["number"].add(1));
      // Spread between invariant plus issuance and new invariant should be less than 0.001e18
      expect(invariant.add(issuance).sub(newInvariant)).to.be.at.most(eth(0.001));
    });

    it("Should not change the interest rate", async function () {
      const auction = await this.auctionHouse.auction();
      const DURATION = await this.auctionHouse.DURATION();
      const endTime = auction["startTime"].add(DURATION);
      // Bid 1 ETH
      await this.auctionHouse.bid({ value: eth(1) });
      // End the auction
      await setTime(endTime.toNumber());
      // Get the interest rate prior to creating the auction
      const interestRate = await this.orchestrator.interestRate();
      // Settle the auction
      await this.auctionHouse.settleCurrentAndCreateNewAuction();
      // Compare the new interest rate
      const newInterestRate = await this.orchestrator.interestRate();
      if (newInterestRate.gt(interestRate)) {
        expect(newInterestRate.sub(interestRate)).to.be.at.most(eth(0.00001));
      } else {
        expect(interestRate.sub(newInterestRate)).to.be.at.most(eth(0.00001));
      }
      expect(newInterestRate).to.equal(interestRate);
    });

    it("Should roll auction house balance and issue correct amount if prior auction was not won", async function () {
      const auction = await this.auctionHouse.auction();
      const DURATION = await this.auctionHouse.DURATION();
      const endTime = auction["startTime"].add(DURATION);
      // End the auction
      await setTime(endTime.toNumber());
      // Get the auction house share balance prior to settling the auction
      const mBalance = await this.mShare.balanceOf(this.auctionHouse.address);
      const bBalance = await this.bShare.balanceOf(this.auctionHouse.address);
      // Calculate invariant prior to settling the auction
      const mShareSupply = await this.mShare.totalSupply();
      const bShareSupply = await this.bShare.totalSupply();
      const invariant = sqrt(sumOfSquares(mShareSupply, bShareSupply).div(eth(1)));
      // Calculate the amount of mShares and bShares to mint
      const issuance = await this.auctionHouse.getInvariantIssuance(auction["number"].add(1));
      const mAmount = mShareSupply.mul(issuance).div(invariant);
      const bAmount = bShareSupply.mul(issuance).div(invariant);
      // Settle the auction
      await this.auctionHouse.settleCurrentAndCreateNewAuction();
      // Compare the new auction house share balance
      expect(await this.mShare.balanceOf(this.auctionHouse.address)).to.equal(mBalance.add(mAmount));
      expect(await this.bShare.balanceOf(this.auctionHouse.address)).to.equal(bBalance.add(bAmount));
    });

    it("Should issue correct amount to auction house if prior auction was won", async function () {
      const auction = await this.auctionHouse.auction();
      const DURATION = await this.auctionHouse.DURATION();
      const endTime = auction["startTime"].add(DURATION);
      // Bid 1 ETH
      await this.auctionHouse.bid({ value: eth(1) });
      // End the auction
      await setTime(endTime.toNumber());
      // Calculate invariant prior to settling the auction
      const mShareSupply = await this.mShare.totalSupply();
      const bShareSupply = await this.bShare.totalSupply();
      const invariant = sqrt(sumOfSquares(mShareSupply, bShareSupply).div(eth(1)));
      // Calculate the amount of mShares and bShares to mint
      const issuance = await this.auctionHouse.getInvariantIssuance(auction["number"].add(1));
      const mAmount = mShareSupply.mul(issuance).div(invariant);
      const bAmount = bShareSupply.mul(issuance).div(invariant);
      // Settle the auction
      await this.auctionHouse.settleCurrentAndCreateNewAuction();
      // Compare the new auction house share balance
      expect(await this.mShare.balanceOf(this.auctionHouse.address)).to.equal(mAmount);
      expect(await this.bShare.balanceOf(this.auctionHouse.address)).to.equal(bAmount);
    });

    it("Should emit AuctionCreated event", async function () {
      const auction = await this.auctionHouse.auction();
      const DURATION = await this.auctionHouse.DURATION();
      const endTime = auction["startTime"].add(DURATION);
      // Bid 1 ETH
      await this.auctionHouse.bid({ value: eth(1) });
      // End the auction
      await setTime(endTime.toNumber());
      // Calculate invariant prior to settling the auction
      const mShareSupply = await this.mShare.totalSupply();
      const bShareSupply = await this.bShare.totalSupply();
      const invariant = sqrt(sumOfSquares(mShareSupply, bShareSupply).div(eth(1)));
      // Calculate the amount of mShares and bShares to mint
      const issuance = await this.auctionHouse.getInvariantIssuance(auction["number"].add(1));
      const mAmount = mShareSupply.mul(issuance).div(invariant);
      const bAmount = bShareSupply.mul(issuance).div(invariant);
      // Verify the AuctionSettled event is emitted correctly
      const newAuctionNumber = auction["number"].add(1);
      const newStartTime = (await getTime()) + 1; // Calling function will increment time by 1
      const newEndTime = newStartTime + DURATION.toNumber();
      await expect(await this.auctionHouse.settleCurrentAndCreateNewAuction())
        .to.emit(this.auctionHouse, "AuctionCreated")
        .withArgs(newAuctionNumber, mAmount, bAmount, newStartTime, newEndTime);
    });
  });
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
