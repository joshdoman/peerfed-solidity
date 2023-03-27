import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";

import type {
  BaseERC20,
  ScaledERC20,
  PeerFedAuctionHouse,
  PeerFedConverter,
  PeerFedOrchestrator,
} from "../src/types/contracts";

type Fixture<T> = () => Promise<T>;

declare module "mocha" {
  export interface Context {
    orchestrator: PeerFedOrchestrator;
    mShare: BaseERC20;
    bShare: BaseERC20;
    mToken: ScaledERC20;
    bToken: ScaledERC20;
    converter: PeerFedConverter;
    auctionHouse: PeerFedAuctionHouse;
    loadFixture: <T>(fixture: Fixture<T>) => Promise<T>;
    signers: Signers;
  }
}

export interface Signers {
  owner: SignerWithAddress;
  addr1: SignerWithAddress;
  addr2: SignerWithAddress;
}
