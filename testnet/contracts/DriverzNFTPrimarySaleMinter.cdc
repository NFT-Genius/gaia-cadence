import NonFungibleToken from 0x631e88ae7f1d7c20
import GaiaPrimarySale from 0x8cd1880bb292c236
import DriverzNFT from 0xf44b704689c35798

pub contract DriverzNFTPrimarySaleMinter {
    pub resource Minter: GaiaPrimarySale.IMinter {
        access(self) let setMinter: @DriverzNFT.SetMinter

        pub fun mint(assetID: UInt64, creator: Address): @NonFungibleToken.NFT {
            return <- self.setMinter.mint(templateID: assetID, creator: creator)
        }

        init(setMinter: @DriverzNFT.SetMinter) {
            self.setMinter <- setMinter
        }

        destroy() {
            destroy self.setMinter
        }
    }

    pub fun createMinter(setMinter: @DriverzNFT.SetMinter): @Minter {
        return <- create Minter(setMinter: <- setMinter)
    }
}
