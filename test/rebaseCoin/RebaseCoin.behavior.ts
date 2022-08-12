import { expect } from "chai";
import { BigNumber } from "ethers";
import { ethers } from "hardhat";

import type { RebaseBond } from "../../src/types/contracts";
import {
  Context,
  createSampleBond,
  eth,
  expire,
  getOraclePrice,
  getTime,
  purchaseBonds,
} from "./BondOrchestrator.behavior";

export function shouldBehaveLikeRebaseCoin(): void {
  describe("Deployment", function () {
    // NOTE: Token currently not "Ownable"
    // it("Should set the right owner", async function () {
    //     // This test expects the owner variable stored in the contract to be
    //     // equal to our Signer's owner.
    //     expect(await this.rebaseToken.owner()).to.equal(this.owner.address);
    // });

    it("Should assign the total supply of tokens to the owner", async function () {
      const { owner } = this.signers;

      const ownerBalance = await this.rebaseCoin.balanceOf(owner.address);
      expect(await this.rebaseCoin.totalSupply()).to.equal(ownerBalance);
    });
  });

  describe("Transactions", function () {
    it("Should transfer tokens between accounts", async function () {
      const { owner, addr1, addr2 } = this.signers;

      // Transfer 50 tokens from owner to addr1
      await expect(this.rebaseCoin.transfer(addr1.address, 50)).to.changeTokenBalances(
        this.rebaseCoin,
        [owner, addr1],
        [-50, 50],
      );

      // Transfer 50 tokens from addr1 to addr2
      // We use .connect(signer) to send a transaction from another account
      await expect(this.rebaseCoin.connect(addr1).transfer(addr2.address, 50)).to.changeTokenBalances(
        this.rebaseCoin,
        [addr1, addr2],
        [-50, 50],
      );
    });

    it("Should emit Transfer event", async function () {
      const { owner, addr1, addr2 } = this.signers;

      // Transfer 50 tokens from owner to addr1
      await expect(this.rebaseCoin.transfer(addr1.address, 50))
        .to.emit(this.rebaseCoin, "Transfer")
        .withArgs(owner.address, addr1.address, 50);

      // Transfer 50 tokens from addr1 to addr2
      // We use .connect(signer) to send a transaction from another account
      await expect(this.rebaseCoin.connect(addr1).transfer(addr2.address, 50))
        .to.emit(this.rebaseCoin, "Transfer")
        .withArgs(addr1.address, addr2.address, 50);
    });

    it("Should fail if sender doesn't have enough tokens", async function () {
      const { owner, addr1 } = this.signers;

      const initialOwnerBalance = await this.rebaseCoin.balanceOf(owner.address);

      // Try to send 1 token from addr1 (0 tokens) to owner (1000 tokens).
      // `require` will evaluate false and revert the transaction.
      await expect(this.rebaseCoin.connect(addr1).transfer(owner.address, 1)).to.be.revertedWith(
        "ERC20: transfer amount exceeds balance",
      );

      // owner balance shouldn't have changed.
      expect(await this.rebaseCoin.balanceOf(owner.address)).to.equal(initialOwnerBalance);
    });
  });

  describe("Rebase", function () {
    it("Should increase supply after rebase", async function () {
      const initialSupply = await this.rebaseCoin.totalSupply();

      // Rebase supply by 150%
      const rebaseFactor = BigNumber.from("1500000000000000000"); // 1.5 * 1e18
      const decimals = BigNumber.from("1000000000000000000"); // 1e18
      const expectedSupply = initialSupply.mul(rebaseFactor).div(decimals);
      await this.rebaseCoin.rebase(rebaseFactor);
      const rebasedSupply = await this.rebaseCoin.totalSupply();
      await expect(rebasedSupply).to.equal(expectedSupply);
    });

    it("Should emit Rebase event", async function () {
      // Rebase supply by 150%
      const rebaseFactor = BigNumber.from("1500000000000000000"); // 1.5 * 1e18
      await expect(this.rebaseCoin.rebase(rebaseFactor)).to.emit(this.rebaseCoin, "Rebase").withArgs(rebaseFactor);
    });
  });

  describe("Rebase2", function () {
    it("Should rebase correctly if current bond has yet to expire", async function () {
      const context = this as unknown as Context;
      const { bond } = await createSampleBond(context);
      // Purchase bonds from Uniswap
      await purchaseBonds(context, bond, eth(10));
      // Change timestamp so that it's halfway between now and the bond's expiration
      const { expiresAt } = await halfWayToExpiration(context, bond);
      // Prepare variables for `expectedCoinsPerToken` calculation
      const { oraclePrice } = await getOraclePrice(context, bond);
      const currentCoinsPerToken = await this.rebaseCoin.coinsPerToken();
      const lastRebasedAt = await this.rebaseCoin.lastRebasedAt();
      // Call rebase function
      await this.rebaseCoin.rebase2();
      // Calculate `expectedCoinsPerToken` (call after rebasing so timestamp calc is the same)
      const newTimestamp = BigNumber.from(await getTime());
      const coinsPerTokenAtExpiration = eth(1).mul(eth(1)).div(oraclePrice);
      let expectedCoinsPerToken;
      if (coinsPerTokenAtExpiration.gt(currentCoinsPerToken)) {
        const deltaPerSecond = coinsPerTokenAtExpiration
          .sub(currentCoinsPerToken)
          .mul(eth(1))
          .div(expiresAt.sub(lastRebasedAt));
        expectedCoinsPerToken = currentCoinsPerToken.add(
          deltaPerSecond.mul(newTimestamp.sub(lastRebasedAt)).div(eth(1)),
        );
      } else {
        const deltaPerSecond = currentCoinsPerToken
          .sub(coinsPerTokenAtExpiration)
          .mul(eth(1))
          .div(expiresAt.sub(lastRebasedAt));
        expectedCoinsPerToken = currentCoinsPerToken.sub(
          deltaPerSecond.mul(newTimestamp.sub(lastRebasedAt)).div(eth(1)),
        );
      }
      expect(await this.rebaseCoin.coinsPerToken()).to.equal(expectedCoinsPerToken);
    });

    it("Should rebase correctly if current bond has expired", async function () {
      const context = this as unknown as Context;
      const { bond } = await createSampleBond(context);
      // Purchase bonds from Uniswap
      await purchaseBonds(context, bond, eth(10));
      // Expire bond
      await expire(context, bond);
      // Get `expectedCoinsPerToken`
      const { oraclePrice } = await getOraclePrice(context, bond);
      const expectedCoinsPerToken = eth(1).mul(eth(1)).div(oraclePrice); // 1e36 / price
      // Call rebase function
      await this.rebaseCoin.rebase2();
      expect(await this.rebaseCoin.coinsPerToken()).to.equal(expectedCoinsPerToken);
    });

    it("Should finalize bond if current bond has expired", async function () {
      const context = this as unknown as Context;
      const { bond } = await createSampleBond(context);
      // Expire bond
      await expire(context, bond);
      // Call rebase function
      await this.rebaseCoin.rebase2();
      expect(await this.bondOrchestrator.isFinalized(bond.address)).to.equal(true);
    });

    it("Should emit Rebase event", async function () {
      const context = this as unknown as Context;
      const { bond } = await createSampleBond(context);
      // Purchase bonds from Uniswap
      await purchaseBonds(context, bond, eth(10));
      // Expire bond
      await expire(context, bond);
      // Get final price from oracle
      const { oraclePrice } = await getOraclePrice(context, bond);
      // Calcualate expected rebase factor
      const expectedCoinsPerToken = eth(1).mul(eth(1)).div(oraclePrice); // 1e36 / price
      const rebaseFactor = expectedCoinsPerToken.mul(eth(1)).div(await this.rebaseCoin.coinsPerToken());
      // Call rebase function and test if `Rebase` event is emitted
      await expect(this.rebaseCoin.rebase2()).to.emit(this.rebaseCoin, "Rebase").withArgs(rebaseFactor);
    });
  });
}

// ----- Helpers -----

export async function halfWayToExpiration(
  context: Context,
  bond: RebaseBond,
): Promise<{ newTimestamp: BigNumber; expiresAt: BigNumber }> {
  // Set timestamp to halway between now and the bond's expiry
  const timestamp = await getTime();
  const expiresAt = await bond.expiresAt();
  const halfway = Math.floor((timestamp + expiresAt.toNumber()) / 2);
  await ethers.provider.send("evm_mine", [halfway]);
  const newTimestamp = BigNumber.from(halfway);
  return { newTimestamp, expiresAt };
}
