import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";

import type {
  FlatExchange,
  FlatExchangeFactory,
  Flatcoin,
  FlatcoinBond,
  FlatcoinTotal,
  FlatcoinIssuanceToken,
  Orchestrator,
  UnmintedFlatcoin,
} from "../src/types/contracts";

type Fixture<T> = () => Promise<T>;

declare module "mocha" {
  export interface Context {
    flatcoin: Flatcoin;
    flatcoinBond: FlatcoinBond;
    unmintedFlatcoin: UnmintedFlatcoin;
    flatcoinTotal: FlatcoinTotal;
    issuanceToken: FlatcoinIssuanceToken;
    orchestrator: Orchestrator;
    exchange: FlatExchange;
    factory: FlatExchangeFactory;
    loadFixture: <T>(fixture: Fixture<T>) => Promise<T>;
    signers: Signers;
  }
}

export interface Signers {
  owner: SignerWithAddress;
  addr1: SignerWithAddress;
  addr2: SignerWithAddress;
}
