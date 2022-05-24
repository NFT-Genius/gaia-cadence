import DriverzNFT from 0xa039bd7d55a96c0c
import NonFungibleToken from 0x1d7e57aa55817448

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

