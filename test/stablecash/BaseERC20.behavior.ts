import { expect } from "chai";

export function shouldBehaveLikeBaseERC20(): void {
    describe("Transactions", function () {
      it("Should transfer tokens between accounts", async function () {
        const { owner, addr1, addr2 } = this.signers;

        // Transfer 50 tokens from owner to addr1
        await expect(this.mShare.transfer(addr1.address, 50)).to.changeTokenBalances(
          this.mShare,
          [owner, addr1],
          [-50, 50],
        );

        // Transfer 50 tokens from addr1 to addr2
        // We use .connect(signer) to send a transaction from another account
        await expect(this.mShare.connect(addr1).transfer(addr2.address, 50)).to.changeTokenBalances(
          this.mShare,
          [addr1, addr2],
          [-50, 50],
        );
      });

      it("Should emit Transfer event", async function () {
        const { owner, addr1, addr2 } = this.signers;

        // Transfer 50 tokens from owner to addr1
        await expect(this.mShare.transfer(addr1.address, 50))
          .to.emit(this.mShare, "Transfer")
          .withArgs(owner.address, addr1.address, 50);

        // Transfer 50 tokens from addr1 to addr2
        // We use .connect(signer) to send a transaction from another account
        await expect(this.mShare.connect(addr1).transfer(addr2.address, 50))
          .to.emit(this.mShare, "Transfer")
          .withArgs(addr1.address, addr2.address, 50);
      });

      it("Should fail if sender doesn't have enough tokens", async function () {
        const { owner, addr1 } = this.signers;

        const initialOwnerBalance = await this.mShare.balanceOf(owner.address);

        // Try to send 1 token from addr1 (0 tokens) to owner (1000 tokens).
        // `require` will evaluate false and revert the transaction.
        await expect(this.mShare.connect(addr1).transfer(owner.address, 1)).to.be.revertedWith(
          "ERC20: transfer amount exceeds balance",
        );

        // Owner balance shouldn't have changed.
        expect(await this.mShare.balanceOf(owner.address)).to.equal(initialOwnerBalance);
      });
    });

    describe("Burning", function () {
      it("Should burn tokens from account", async function () {
        const { owner } = this.signers;

        // Burn 50 tokens from owner
        await expect(this.mShare.burn(50)).to.changeTokenBalance(this.mShare, owner, -50);
      });
    });

  // describe("Deployment", function () {
  //   it("Should set flatcoinTotal as the flatcoin swapper", async function () {
  //     expect(await this.flatcoin.swapper()).to.equal(this.flatcoinTotal.address);
  //   });
  //
  //   it("Should set the exchange as the flatcoinTotal and flatcoinBond swapper", async function () {
  //     expect(await this.flatcoinTotal.swapper()).to.equal(this.exchange.address);
  //     expect(await this.flatcoinBond.swapper()).to.equal(this.exchange.address);
  //   });
  //
  //   it("Should forbid resetting the swapper address", async function () {
  //     const { owner } = this.signers;
  //     await expect(this.flatcoin.setSwapper(owner.address)).to.be.revertedWith("Swapper already set");
  //   });
  // });
  //
  // describe("Swaps", function () {
  //   it("Should forbid minting if not swapper", async function () {
  //     const { owner } = this.signers;
  //     await expect(this.flatcoin.mintOnSwap(owner.address, 50)).to.be.revertedWith("Forbidden");
  //   });
  //
  //   it("Should forbid burning if not swapper", async function () {
  //     const { owner } = this.signers;
  //     await expect(this.flatcoin.burnOnSwap(owner.address, 50)).to.be.revertedWith("Forbidden");
  //   });
  // });
}
