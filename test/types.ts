import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";

import type { BaseERC20, PeerFedConverter, PeerFedOrchestrator, ScaledERC20 } from "../src/types/contracts";

type Fixture<T> = () => Promise<T>;

declare module "mocha" {
  export interface Context {
    orchestrator: PeerFedOrchestrator;
    mShare: BaseERC20;
    bShare: BaseERC20;
    mToken: ScaledERC20;
    bToken: ScaledERC20;
    converter: PeerFedConverter;
    loadFixture: <T>(fixture: Fixture<T>) => Promise<T>;
    signers: Signers;
  }
}

export interface Signers {
  owner: SignerWithAddress;
  addr1: SignerWithAddress;
  addr2: SignerWithAddress;
}
