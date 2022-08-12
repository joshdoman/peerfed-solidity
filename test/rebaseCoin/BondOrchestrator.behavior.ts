import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { expect } from "chai";
import { BigNumber, constants, utils } from "ethers";
import { ethers } from "hardhat";
import { IUniswapV2Factory, IUniswapV2Router02 } from "uniswap-v2-deploy-plugin";

import type { BondOrchestrator, RebaseBond, RebaseCoin, RebaseToken } from "../../src/types/contracts";

export function eth(n: number) {
  return utils.parseEther(n.toString());
}

interface Signers {
  owner: SignerWithAddress;
  addr1: SignerWithAddress;
  addr2: SignerWithAddress;
}

export interface Context {
  signers: Signers;
  rebaseCoin: RebaseCoin;
  rebaseToken: RebaseToken;
  bondOrchestrator: BondOrchestrator;
  factory: IUniswapV2Factory;
  router: IUniswapV2Router02;
}

export function shouldBehaveLikeBondOrchestrator(): void {
  describe("Deployment", function () {
    it("Should have no bonds outstanding", async function () {
      const currentBondAddr = await this.bondOrchestrator.currentBond();
      expect(currentBondAddr).to.equal(constants.AddressZero);
    });
  });

  describe("Bond Creation", function () {
    it("Should set the current bond to the new bond", async function () {
      const { bond } = await createSampleBond(this as unknown as Context);

      const currentBondAddr = await this.bondOrchestrator.currentBond();
      expect(currentBondAddr).to.equal(bond.address);
    });

    it("Should set bond expiry", async function () {
      const expiresAt = await createSampleExpiry();
      const redemptionRate = eth(1); // 1e18

      const { bond } = await createBond(this.bondOrchestrator, expiresAt, redemptionRate);

      expect(await bond.expiresAt()).to.equal(expiresAt);
    });

    it("Should set bond redemption rate", async function () {
      const expiresAt = await createSampleExpiry();
      const redemptionRate = eth(1); // 1e18
      const { bond } = await createBond(this.bondOrchestrator, expiresAt, redemptionRate);

      expect(await this.bondOrchestrator.getRedemptionRate(bond.address)).to.equal(redemptionRate);
    });

    it("Should emit BondCreation event", async function () {
      const { owner } = this.signers;
      const sevenDays = 7 * 24 * 60 * 60;
      const timestamp = await getTime();
      const expiresAt = timestamp + sevenDays;
      const redemptionRate = eth(1); // 1e18

      await expect(this.bondOrchestrator.createNewBond(expiresAt, redemptionRate))
        .to.emit(this.bondOrchestrator, "BondCreated")
        .withArgs(owner.address, await this.bondOrchestrator.getBond(expiresAt), redemptionRate);
    });

    it("Should not be finalized", async function () {
      const { bond } = await createSampleBond(this as unknown as Context);

      const isFinalized = await this.bondOrchestrator.isFinalized(bond.address);
      expect(isFinalized).to.equal(false);
    });

    it("Should create Uniswap pair at oracle address", async function () {
      const { bond } = await createSampleBond(this as unknown as Context);

      const oracleAddr = await this.bondOrchestrator.getOracle(bond.address);
      await ethers.getContractAt("IUniswapV2Pair", oracleAddr);
    });

    it("Should set oracle price to the redemption rate", async function () {
      const expiresAt = await createSampleExpiry();
      const redemptionRate = eth(2); // 2 * 1e18
      const { bond } = await createBond(this.bondOrchestrator, expiresAt, redemptionRate);
      const { oraclePrice } = await getOraclePrice(this as unknown as Context, bond);
      expect(oraclePrice).to.equal(redemptionRate);
    });

    it("Should fail if bond already exists at expiry", async function () {
      const expiresAt = await createSampleExpiry();
      const redemptionRate = eth(1);
      await createBond(this.bondOrchestrator, expiresAt, redemptionRate);

      // Try to create a second bond with the same expiry but different redemption rate
      const redemptionRate2 = redemptionRate.mul(2);
      await expect(this.bondOrchestrator.createNewBond(expiresAt, redemptionRate2)).to.be.revertedWith(
        "Bond at that expiry already exists.",
      );
    });

    it("Should fail if bond expires too soon", async function () {
      const expiresAt = await createSampleExpiry();
      const redemptionRate = eth(1);
      await createBond(this.bondOrchestrator, expiresAt, redemptionRate);

      // Try to create a second bond that expires at half the `MIN_TIME_BETWEEN_BONDS`
      const MIN_TIME_BETWEEN_BONDS: BigNumber = await this.bondOrchestrator.MIN_TIME_BETWEEN_BONDS();
      const expiresAt2 = expiresAt + MIN_TIME_BETWEEN_BONDS.toNumber() / 2;
      await expect(this.bondOrchestrator.createNewBond(expiresAt2, redemptionRate)).to.be.revertedWith(
        "Bond expires too soon.",
      );
    });

    it("Should fail if redemption rate is zero", async function () {
      const expiresAt = await createSampleExpiry();
      const redemptionRate = 0;
      await expect(this.bondOrchestrator.createNewBond(expiresAt, redemptionRate)).to.be.revertedWith(
        "Redemption rate must be non-zero.",
      );
    });
  });

  describe("Update", function () {
    it("Should fail if bond has been finalized", async function () {
      const { bond } = await createSampleBond(this as unknown as Context);
      // Set timestamp to the bond's expiry
      const expiresAt = await bond.expiresAt();
      await ethers.provider.send("evm_mine", [expiresAt.toNumber()]);
      // Finalize bond
      await this.bondOrchestrator.finalize(bond.address);

      await expect(this.bondOrchestrator.update(bond.address)).to.be.revertedWith("Bond has been finalized.");
    });

    it("Should update redemption rate to match the oracle", async function () {
      const context = this as unknown as Context;
      const { bond } = await createSampleBond(context);
      // Purchase bonds from Uniswap
      await purchaseBonds(context, bond, eth(10));
      // Update bond
      await this.bondOrchestrator.update(bond.address);
      // Get updated price from oracle
      const { oraclePrice } = await getOraclePrice(context, bond);
      expect(await this.bondOrchestrator.getRedemptionRate(bond.address)).to.equal(oraclePrice);
    });
  });

  describe("Finalize", function () {
    it("Should fail if bond has not expired", async function () {
      const { bond } = await createSampleBond(this as unknown as Context);
      await expect(this.bondOrchestrator.finalize(bond.address)).to.be.revertedWith("Bond has not expired.");
    });

    it("Should finalize bond if it has expired", async function () {
      const context = this as unknown as Context;
      const { bond } = await createSampleBond(context);
      // Finalize bond
      await expireAndFinalize(context, bond);
      // Check if bond has been finalized
      expect(await this.bondOrchestrator.isFinalized(bond.address)).to.equal(true);
    });

    it("Should update redemption rate to match the oracle", async function () {
      const context = this as unknown as Context;
      const { bond } = await createSampleBond(context);
      // Purchase bonds from Uniswap
      await purchaseBonds(context, bond, eth(10));
      // Finalize bond
      await expireAndFinalize(context, bond);
      // Get updated price from oracle
      const { oraclePrice } = await getOraclePrice(context, bond);
      // Verify redemption rate is the same as the final price on the oracle
      expect(await this.bondOrchestrator.getRedemptionRate(bond.address)).to.equal(oraclePrice);
    });

    it("Should block swaps with the oracle between expiry and finalization", async function () {
      const context = this as unknown as Context;
      const { bond } = await createSampleBond(context);
      // Purchase bonds from Uniswap (so that we can try selling them later)
      await purchaseBonds(context, bond, eth(10));
      // Expire bond
      await expire(context, bond);
      // Try to purchase bonds from Uniswap
      await expect(purchaseBonds(context, bond, eth(1))).to.be.revertedWith("UniswapV2: TRANSFER_FAILED");
      // Try to sell bonds to Uniswap
      await expect(sellBonds(context, bond, eth(1))).to.be.revertedWith("TransferHelper: TRANSFER_FROM_FAILED");
    });

    it("Should allow transfers to and from the oracle after bond is finalized", async function () {
      const context = this as unknown as Context;
      const { bond } = await createSampleBond(context);
      // Expire bond
      await expireAndFinalize(context, bond);
      // Try to purchase bonds from Uniswap
      await purchaseBonds(context, bond, eth(10));
      // Try to sell bonds to Uniswap
      await sellBonds(context, bond, eth(1));
    });
  });

  describe("Bond Redemption", function () {
    it("Should fail if bond is not finalized", async function () {
      const { bond } = await createSampleBond(this as unknown as Context);
      await expect(this.bondOrchestrator.redeem(bond.address)).to.be.revertedWith("Bond has not been finalized.");
    });

    it("Should burn owner's bonds upon redemption", async function () {
      const context = this as unknown as Context;
      const { owner } = context.signers;
      const { bond } = await createSampleBond(context);
      // Purchase 10 bonds from Uniswap
      await purchaseBonds(context, bond, eth(10));
      // Expire bond
      await expireAndFinalize(context, bond);
      // Redeem owner's bonds
      this.bondOrchestrator.redeem(bond.address);

      expect(await bond.balanceOf(owner.address)).to.equal(0);
    });

    it("Should mint tokens at the redemption rate", async function () {
      // TODO: Implement
      const context = this as unknown as Context;
      const { owner } = context.signers;
      const { bond } = await createSampleBond(context);
      // Purchase 10 bonds from Uniswap and then expire and finalize the bond
      await purchaseBonds(context, bond, eth(10));
      await expireAndFinalize(context, bond);
      // Get redemption rate and calculate expected mint from bond balance
      const redemptionRate = await this.bondOrchestrator.getRedemptionRate(bond.address);
      const bondBalance = await bond.balanceOf(owner.address);
      const expectedMint = bondBalance.mul(redemptionRate).div(eth(1));
      // Verify owner's balance increased by the expected mint amount
      await expect(this.bondOrchestrator.redeem(bond.address)).to.changeTokenBalance(
        this.rebaseToken,
        owner.address,
        expectedMint,
      );
    });
  });
}

// ----- Helper Functions -----

export async function getTime(): Promise<number> {
  const blockNumBefore = await ethers.provider.getBlockNumber();
  const blockBefore = await ethers.provider.getBlock(blockNumBefore);
  return blockBefore.timestamp;
}

export async function createSampleExpiry(): Promise<number> {
  // Returns now plus 7 days
  const sevenDays = 7 * 24 * 60 * 60;
  const timestamp = await getTime();
  return timestamp + sevenDays;
}

export async function createSampleBond(context: Context): Promise<{ bond: RebaseBond }> {
  const expiresAt = await createSampleExpiry();
  const redemptionRate = eth(1); // 1e18
  return await createBond(context.bondOrchestrator, expiresAt, redemptionRate);
}

export async function createBond(
  bondOrchestrator: BondOrchestrator,
  expiresAt: number,
  redemptionRate: BigNumber,
): Promise<{ bond: RebaseBond }> {
  await bondOrchestrator.createNewBond(expiresAt, redemptionRate);
  const bondAddr = await bondOrchestrator.getBond(expiresAt);
  return await loadBond(bondAddr);
}

export async function loadBond(bondAddr: string): Promise<{ bond: RebaseBond }> {
  const bond: RebaseBond = <RebaseBond>await ethers.getContractAt("RebaseBond", bondAddr);
  return { bond };
}

export async function purchaseBonds(context: Context, bond: RebaseBond, amount: BigNumber): Promise<void> {
  const { owner } = context.signers;
  // Approve UniswapV2 pair's ability to transfer tokens
  await context.rebaseToken.approve(context.router.address, amount);
  // Swap tokens with UniswapV2 pair
  await context.router.swapExactTokensForTokens(
    amount,
    0,
    [context.rebaseToken.address, bond.address],
    owner.address,
    constants.MaxUint256,
  );
}

export async function sellBonds(context: Context, bond: RebaseBond, amount: BigNumber): Promise<void> {
  const { owner } = context.signers;
  // Approve UniswapV2 pair's ability to transfer tokens
  await bond.approve(context.router.address, amount);
  // Swap tokens with UniswapV2 pair
  await context.router.swapExactTokensForTokens(
    amount,
    0,
    [bond.address, context.rebaseToken.address],
    owner.address,
    constants.MaxUint256,
  );
}

export async function getOraclePrice(context: Context, bond: RebaseBond): Promise<{ oraclePrice: BigNumber }> {
  // Get pair
  const oracleAddr = await context.bondOrchestrator.getOracle(bond.address);
  const pair = await ethers.getContractAt("IUniswapV2Pair", oracleAddr);
  // Calculate current price from reserves
  const { reserve0, reserve1 } = await pair.getReserves();
  const bondReserve = bond.address < context.rebaseToken.address ? reserve0 : reserve1;
  const tokenReserve = bond.address < context.rebaseToken.address ? reserve1 : reserve0;
  const oraclePrice = tokenReserve.mul(eth(1)).div(bondReserve);
  return { oraclePrice };
}

export async function expire(context: Context, bond: RebaseBond): Promise<void> {
  // Set timestamp to the bond's expiry
  const expiresAt = await bond.expiresAt();
  await ethers.provider.send("evm_mine", [expiresAt.toNumber()]);
}

export async function expireAndFinalize(context: Context, bond: RebaseBond): Promise<void> {
  // Expire bond
  await expire(context, bond);
  // Finalize bond
  await context.bondOrchestrator.finalize(bond.address);
}
