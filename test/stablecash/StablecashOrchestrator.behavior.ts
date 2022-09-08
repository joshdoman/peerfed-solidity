import { expect } from "chai";
import { utils } from "ethers";

export function shouldBehaveLikeStablecashOrchestrator(): void {
  describe("Deployment", function () {
    it("Should assign the total supply of shares to the deployer", async function () {
      const { owner } = this.signers;

      const ownerMShareBalance = await this.mShare.balanceOf(owner.address);
      expect(await this.mShare.totalSupply()).to.equal(ownerMShareBalance);

      const ownerBShareBalance = await this.bShare.balanceOf(owner.address);
      expect(await this.bShare.totalSupply()).to.equal(ownerBShareBalance);
    });

    it("Should set the starting scale factor equal to one", async function () {
      expect(await this.orchestrator.scaleFactor()).to.equal(eth(1));
    });
  });
}

function eth(n: number) {
  return utils.parseEther(n.toString());
}
