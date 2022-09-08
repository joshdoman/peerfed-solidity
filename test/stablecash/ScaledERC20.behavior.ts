import { expect } from "chai";
import { BigNumber } from "ethers";
import type { Context } from "mocha";

import { eth } from "./StablecashFactory.behavior";

export function shouldBehaveLikeScaledERC20(): void {
  describe("Supply", function () {
    it("Should calculate total supply using total base supply and current scale factor", async function () {
      const shareSupply = await this.mShare.totalSupply();
      const expectedTokenSupply = await equivalentTokenAmount(this, shareSupply);
      expect(await this.mToken.totalSupply()).to.equal(expectedTokenSupply);
    });
  });

  describe("Balance", function () {
    it("Should calculate balance using base balance and current scale factor", async function () {
      const { owner } = this.signers;

      const shareBalance = await this.mShare.balanceOf(owner.address);
      const expectedTokenBalance = await equivalentTokenAmount(this, shareBalance);
      expect(await this.mToken.balanceOf(owner.address)).to.equal(expectedTokenBalance);
    });
  });

  describe("Transactions", function () {
    it("Should transfer tokens between accounts", async function () {
      const { owner, addr1, addr2 } = this.signers;

      // Should transfer share equivalent of 50 tokens from owner to addr1
      const ownerShareBalance = await this.mShare.balanceOf(owner.address);
      const addr1ShareBalance1 = await this.mShare.balanceOf(addr1.address);
      await this.mToken.transfer(addr1.address, 50);
      const expectedOwnerTokenBalance = await expectedTokenBalance(this, ownerShareBalance, -50);
      const expectedAddr1TokenBalance1 = await expectedTokenBalance(this, addr1ShareBalance1, 50);
      expect(await this.mToken.balanceOf(owner.address)).to.equal(expectedOwnerTokenBalance);
      expect(await this.mToken.balanceOf(addr1.address)).to.equal(expectedAddr1TokenBalance1);

      // Should transfer share equivalent of 20 tokens from addr1 to addr2
      const addr1ShareBalance2 = await this.mShare.balanceOf(addr1.address);
      const addr2ShareBalance = await this.mShare.balanceOf(addr2.address);
      await this.mToken.connect(addr1).transfer(addr2.address, 20);
      const expectedAddr1TokenBalance2 = await expectedTokenBalance(this, addr1ShareBalance2, -20);
      const expectedAddr2TokenBalance = await expectedTokenBalance(this, addr2ShareBalance, 20);
      expect(await this.mToken.balanceOf(addr1.address)).to.equal(expectedAddr1TokenBalance2);
      expect(await this.mToken.balanceOf(addr2.address)).to.equal(expectedAddr2TokenBalance);
    });

    it("Should emit Transfer event", async function () {
      const { owner, addr1, addr2 } = this.signers;

      // Transfer 50 tokens from owner to addr1
      await expect(this.mToken.transfer(addr1.address, 50))
        .to.emit(this.mToken, "Transfer")
        .withArgs(owner.address, addr1.address, 50);

      // Transfer 50 tokens from addr1 to addr2
      // We use .connect(signer) to send a transaction from another account
      await expect(this.mToken.connect(addr1).transfer(addr2.address, 50))
        .to.emit(this.mToken, "Transfer")
        .withArgs(addr1.address, addr2.address, 50);
    });

    it("Should fail if sender doesn't have enough tokens", async function () {
      const { owner, addr1 } = this.signers;

      const initialOwnerShareBalance = await this.mShare.balanceOf(owner.address);

      // Try to send 10 tokens from addr1 (0 tokens) to owner (1000 tokens).
      // `require` will evaluate false and revert the transaction.
      await expect(this.mToken.connect(addr1).transfer(owner.address, 10)).to.be.revertedWith(
        "ERC20: transfer amount exceeds balance",
      );

      // Owner share balance shouldn't have changed.
      expect(await this.mShare.balanceOf(owner.address)).to.equal(initialOwnerShareBalance);
    });
  });

  describe("Burning", function () {
    it("Should burn tokens from account", async function () {
      const { owner } = this.signers;

      // Burn share equivalent of 50 tokens from owner
      const ownerShareBalance = await this.mShare.balanceOf(owner.address);
      await this.mToken.burn(50);
      const expectedOwnerTokenBalance = await expectedTokenBalance(this, ownerShareBalance, -50);
      expect(await this.mToken.balanceOf(owner.address)).to.equal(expectedOwnerTokenBalance);
    });
  });
}

// Calculates the token balance implied by the starting share balance and token transfer amount
export async function expectedTokenBalance(
  context: Context,
  startingShares: BigNumber,
  transferAmount: number,
): Promise<BigNumber> {
  const sharesTransferred = await equivalentShareAmount(context, BigNumber.from(Math.abs(transferAmount)));
  let expectedShareBalance: BigNumber;
  if (transferAmount > 0) {
    expectedShareBalance = startingShares.add(sharesTransferred);
  } else {
    expectedShareBalance = startingShares.sub(sharesTransferred);
  }
  return await equivalentTokenAmount(context, expectedShareBalance);
}

// Calculates the equivalent number of shares of a given token amount
export async function equivalentShareAmount(context: Context, tokenAmount: BigNumber): Promise<BigNumber> {
  const scaleFactor = await context.factory.scaleFactor();
  return tokenAmount.mul(eth(1)).div(scaleFactor);
}

// Calculates the equivalent number of tokens of a given share amount
export async function equivalentTokenAmount(context: Context, shareAmount: BigNumber): Promise<BigNumber> {
  const scaleFactor = await context.factory.scaleFactor();
  return shareAmount.mul(scaleFactor).div(eth(1));
}
