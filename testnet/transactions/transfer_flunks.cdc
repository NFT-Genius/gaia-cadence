import FungibleToken from 0x9a0766d93b6608b7
import NonFungibleToken from 0x631e88ae7f1d7c20
import DapperUtilityCoin from 0x82ec283f88a62e65
import Flunks from 0xe666c53e1758dec6
import NFTStorefront from 0x94b06cfca1d8a476

transaction(assetID: UInt64, to: Address) {
    let flunksProvider: &Flunks.Collection
    let flunksReceiver: &Flunks.Collection{NonFungibleToken.CollectionPublic, Flunks.FlunksCollectionPublic}

    prepare(acct: AuthAccount) {
        self.flunksProvider = acct.borrow<&Flunks.Collection>(from: Flunks.CollectionStoragePath)!

        self.flunksReceiver = getAccount(to).getCapability<&Flunks.Collection{NonFungibleToken.CollectionPublic, Flunks.FlunksCollectionPublic}>(Flunks.CollectionPublicPath)
            .borrow()
            ?? panic("Could not borrow receiver reference")
    }

    execute {
        self.flunksReceiver.deposit(token: <- self.flunksProvider.withdraw(withdrawID: assetID))
    }
}
