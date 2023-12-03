import { sqrt } from "@prb/math";
import { expect } from "chai";
import { parseEther } from "ethers/lib/utils";

export function shouldBehaveLikePeerFedLibrary(): void {
  describe("Quote", function () {
    it("Should correctly calculate quote for pair swap", async function () {
      expect(await this.library.quote(eth(1), eth(10), eth(2))).to.equal(eth(5));
    });
  });

  describe("Interest Rate", function () {
    it("Should correctly calculate interest rate when supplyA > supplyB", async function () {
      const supplyA = eth(20);
      const supplyB = eth(10);
      expect(await this.library.interestRate(supplyA, supplyB)).to.equal(
        supplyA.sub(supplyB).mul(eth(1)).div(supplyA.add(supplyB)),
      );
    });

    it("Should return zero if supplyA < supplyB", async function () {
      const supplyA = eth(10);
      const supplyB = eth(20);
      expect(await this.library.interestRate(supplyA, supplyB)).to.equal(0);
    });
  });

  describe("Swap", function () {
    it("Should correctly calculate amount out on swap given amount in", async function () {
      const amountAIn = eth(1);
      const supplyA = eth(100);
      const supplyB = eth(200);
      const invariantSq = supplyA.mul(supplyA).add(supplyB.mul(supplyB));
      const newSupplyA = supplyA.sub(amountAIn);
      const newSupplyB = sqrt(invariantSq.sub(newSupplyA.mul(newSupplyA)).div(eth(1)));
      const amountBOut = newSupplyB.sub(supplyB);
      expect(await this.library.getAmountOut(amountAIn, supplyA, supplyB)).to.equal(amountBOut);
    });

    it("Should correctly calculate amount in on swap given amount out", async function () {
      const amountBOut = eth(1);
      const supplyA = eth(100);
      const supplyB = eth(200);
      const invariantSq = supplyA.mul(supplyA).add(supplyB.mul(supplyB));
      const newSupplyB = supplyB.add(amountBOut);
      const newSupplyA = sqrt(invariantSq.sub(newSupplyB.mul(newSupplyB)).div(eth(1)));
      const amountAIn = supplyA.sub(newSupplyA);
      expect(await this.library.getAmountIn(amountBOut, supplyA, supplyB)).to.equal(amountAIn);
    });
  });
}

export function eth(n: number) {
  return parseEther(n.toString());
}
