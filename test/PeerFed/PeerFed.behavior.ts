import { time } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { BigNumber } from "ethers";
import { ethers } from "hardhat";

export function shouldBehaveLikePeerFed(): void {}

export function eth(n: number) {
  return ethers.utils.parseEther(n.toString());
}
