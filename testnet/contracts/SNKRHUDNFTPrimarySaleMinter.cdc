import NonFungibleToken from 0x631e88ae7f1d7c20
import GaiaPrimarySale from 0x8cd1880bb292c236
import SNKRHUDNFT from 0x9a85ed382b96c857

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
