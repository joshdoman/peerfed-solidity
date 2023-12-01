import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";

import type { PeerFed, PeerFedLibraryExternal, SwappableERC20 } from "../src/types/contracts";

type Fixture<T> = () => Promise<T>;

declare module "mocha" {
  export interface Context {
    peerfed: PeerFed;
    token0: SwappableERC20;
    token1: SwappableERC20;
    library: PeerFedLibraryExternal;
    loadFixture: <T>(fixture: Fixture<T>) => Promise<T>;
    signers: Signers;
  }
}

export interface Signers {
  owner: SignerWithAddress;
  addr1: SignerWithAddress;
  addr2: SignerWithAddress;
}
