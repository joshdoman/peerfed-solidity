import { ethers } from "hardhat";

export function shouldBehaveLikePeerFedLibrary(): void {}

export function eth(n: number) {
  return ethers.utils.parseEther(n.toString());
}
