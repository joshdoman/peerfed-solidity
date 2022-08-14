import { expect } from "chai";

export function shouldBehaveLikeERC20Swappable(): void {
  describe("Deployment", function () {
    it("Should set the swapper address", async function () {
      const { owner } = this.signers;

      // For testing purposes, set the owner as the swapper address
      await this.flatcoin.setSwapper(owner.address);
      expect(await this.flatcoin.swapper()).to.equal(owner.address);
    });

    it("Should forbid resetting the swapper address", async function () {
      const { owner, addr1 } = this.signers;

      await this.flatcoin.setSwapper(owner.address);
      await expect(this.flatcoin.setSwapper(addr1.address)).to.be.revertedWith(
        "Swapper already set",
      );
    });
  });

  describe("Swaps", function () {
      it("Should allow swapper to mint tokens to any account", async function () {
        const { owner, addr1 } = this.signers;

        await this.flatcoin.setSwapper(owner.address);
        await expect(this.flatcoin.mintToOnSwap(addr1.address, 50)).to.changeTokenBalance(
          this.flatcoin,
          addr1,
          50,
        );
      });

      it("Should allow swapper to burn tokens from any account", async function () {
        const { owner, addr1 } = this.signers;

        await this.flatcoin.setSwapper(owner.address);
        await this.flatcoin.transfer(addr1.address, 50);
        await expect(this.flatcoin.burnFromOnSwap(addr1.address, 50)).to.changeTokenBalance(
          this.flatcoin,
          addr1,
          -50,
        );
      });

      it("Should forbid minting if not swapper", async function () {
        const { owner } = this.signers;
        await expect(this.flatcoin.mintToOnSwap(owner.address, 50)).to.be.revertedWith(
          "Forbidden",
        );
      });

      it("Should forbid burning if not swapper", async function () {
          const { owner } = this.signers;
          await expect(this.flatcoin.burnFromOnSwap(owner.address, 50)).to.be.revertedWith(
            "Forbidden",
          );
      });
  });
}
