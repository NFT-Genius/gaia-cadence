import NonFungibleToken from 0x631e88ae7f1d7c20
import GaiaPrimarySale from 0x8cd1880bb292c236
import DugoutDawgzNFT from 0x44eb6c679f0a4adc

pub contract DugoutDawgzNFTPrimarySaleMinter {
    pub resource Minter: GaiaPrimarySale.IMinter {
        access(self) let setMinter: @DugoutDawgzNFT.SetMinter

        pub fun mint(assetID: UInt64, creator: Address): @NonFungibleToken.NFT {
            return <- self.setMinter.mint(templateID: assetID, creator: creator)
        }

        init(setMinter: @DugoutDawgzNFT.SetMinter) {
            self.setMinter <- setMinter
        }

        destroy() {
            destroy self.setMinter
        }
    }

    pub fun createMinter(setMinter: @DugoutDawgzNFT.SetMinter): @Minter {
        return <- create Minter(setMinter: <- setMinter)
    }
}
