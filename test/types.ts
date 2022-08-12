import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";

import type { Greeter, RebaseCoin } from "../src/types/contracts";

type Fixture<T> = () => Promise<T>;

declare module "mocha" {
  export interface Context {
    greeter: Greeter;
    rebaseCoin: RebaseCoin;
    loadFixture: <T>(fixture: Fixture<T>) => Promise<T>;
    signers: Signers;
  }
}

export interface Signers {
  owner: SignerWithAddress;
  addr1: SignerWithAddress;
  addr2: SignerWithAddress;
}
