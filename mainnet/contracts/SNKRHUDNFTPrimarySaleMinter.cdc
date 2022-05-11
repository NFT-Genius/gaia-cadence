import NonFungibleToken from 0x1d7e57aa55817448
import GaiaPrimarySale from 0xGaiaPrimarySale
import SNKRHUDNFT from 0xSNKRHUDNFT

pub contract SNKRHUDNFTPrimarySaleMinter {
    pub resource Minter: GaiaPrimarySale.IMinter {
        access(self) let setMinter: @SNKRHUDNFT.SetMinter

        pub fun mint(assetID: UInt64, creator: Address): @NonFungibleToken.NFT {
            return <- self.setMinter.mint(templateID: assetID, creator: creator)
        }

        init(setMinter: @SNKRHUDNFT.SetMinter) {
            self.setMinter <- setMinter
        }

        destroy() {
            destroy self.setMinter
        }
    }

    pub fun createMinter(setMinter: @SNKRHUDNFT.SetMinter): @Minter {
        return <- create Minter(setMinter: <- setMinter)
    }
}
