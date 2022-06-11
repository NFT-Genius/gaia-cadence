import DriverzNFT from 0xf44b704689c35798
import NonFungibleToken from 0x631e88ae7f1d7c20

transaction() {
    let signer: AuthAccount

    prepare(acct: AuthAccount) {
        self.signer = acct
    }

    execute {
        if self.signer.borrow<&DriverzNFT.Collection>(from: DriverzNFT.CollectionStoragePath) == nil {
            let collection <- DriverzNFT.createEmptyCollection() as! @DriverzNFT.Collection
            self.signer.save(<-collection, to: DriverzNFT.CollectionStoragePath)
            self.signer.link<&{NonFungibleToken.CollectionPublic, DriverzNFT.CollectionPublic}>(DriverzNFT.CollectionPublicPath, target: DriverzNFT.CollectionStoragePath)
        }
    }
}

