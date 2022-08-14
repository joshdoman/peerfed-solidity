import { expect } from "chai";

export function shouldBehaveLikeFlatcoinBond(): void {
  describe("Deployment", function () {
    // NOTE: Token currently not "Ownable"
    // it("Should set the right owner", async function () {
    //     // This test expects the owner variable stored in the contract to be
    //     // equal to our Signer's owner.
    //     expect(await this.rebaseToken.owner()).to.equal(this.owner.address);
    // });

    it("Should assign the total supply of tokens to the owner", async function () {
      const { owner } = this.signers;

      const ownerBalance = await this.flatcoinBond.balanceOf(owner.address);
      expect(await this.flatcoinBond.totalSupply()).to.equal(ownerBalance);
    });
  });

  describe("Transactions", function () {
    it("Should transfer tokens between accounts", async function () {
      const { owner, addr1, addr2 } = this.signers;

      // Transfer 50 tokens from owner to addr1
      await expect(this.flatcoinBond.transfer(addr1.address, 50)).to.changeTokenBalances(
        this.flatcoinBond,
        [owner, addr1],
        [-50, 50],
      );

      // Transfer 50 tokens from addr1 to addr2
      // We use .connect(signer) to send a transaction from another account
      await expect(this.flatcoinBond.connect(addr1).transfer(addr2.address, 50)).to.changeTokenBalances(
        this.flatcoinBond,
        [addr1, addr2],
        [-50, 50],
      );
    });

    it("Should emit Transfer event", async function () {
      const { owner, addr1, addr2 } = this.signers;

      // Transfer 50 tokens from owner to addr1
      await expect(this.flatcoinBond.transfer(addr1.address, 50))
        .to.emit(this.flatcoinBond, "Transfer")
        .withArgs(owner.address, addr1.address, 50);

      // Transfer 50 tokens from addr1 to addr2
      // We use .connect(signer) to send a transaction from another account
      await expect(this.flatcoinBond.connect(addr1).transfer(addr2.address, 50))
        .to.emit(this.flatcoinBond, "Transfer")
        .withArgs(addr1.address, addr2.address, 50);
    });

    it("Should fail if sender doesn't have enough tokens", async function () {
      const { owner, addr1 } = this.signers;

      const initialOwnerBalance = await this.flatcoinBond.balanceOf(owner.address);

      // Try to send 1 token from addr1 (0 tokens) to owner (1000 tokens).
      // `require` will evaluate false and revert the transaction.
      await expect(this.flatcoinBond.connect(addr1).transfer(owner.address, 1)).to.be.revertedWith(
        "ERC20: transfer amount exceeds balance",
      );

      // Owner balance shouldn't have changed.
      expect(await this.flatcoinBond.balanceOf(owner.address)).to.equal(initialOwnerBalance);
    });
  });

  describe("Burning", function () {
    it("Should burn tokens from account", async function () {
      const { owner, } = this.signers;

      // Transfer 50 tokens from owner to addr1
      await expect(this.flatcoinBond.burn(50)).to.changeTokenBalance(
        this.flatcoinBond,
        owner,
        -50,
      );
    });
  });
}
