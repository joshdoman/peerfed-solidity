import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";

import type {
  BaseERC20,
  ScaledERC20,
  StablecashAuction,
  StablecashExchange,
  StablecashOrchestrator,
} from "../src/types/contracts";

type Fixture<T> = () => Promise<T>;

declare module "mocha" {
  export interface Context {
    orchestrator: StablecashOrchestrator;
    mShare: BaseERC20;
    bShare: BaseERC20;
    mToken: ScaledERC20;
    bToken: ScaledERC20;
    exchange: StablecashExchange;
    auction: StablecashAuction;
    loadFixture: <T>(fixture: Fixture<T>) => Promise<T>;
    signers: Signers;
  }
}

export interface Signers {
  owner: SignerWithAddress;
  addr1: SignerWithAddress;
  addr2: SignerWithAddress;
}
