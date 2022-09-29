import FungibleToken from 0x9a0766d93b6608b7
import NonFungibleToken from 0x631e88ae7f1d7c20
import DapperUtilityCoin from 0x82ec283f88a62e65
import Gaia from 0x40e47dca6a761db7
import NFTStorefront from 0x94b06cfca1d8a476

transaction(assetID: UInt64, to: Address) {
    let gaiaProvider: Capability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>
    let gaiaReceiver: &{Gaia.CollectionPublic}

    prepare(acct: AuthAccount) {
        // We need a provider capability, but one is not provided by default so we create one if needed.
        let gaiaCollectionProviderPrivatePath = /private/GaiaCollectionProviderForNFTStorefront

        if !acct.getCapability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>(gaiaCollectionProviderPrivatePath)!.check() {
            acct.link<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>(gaiaCollectionProviderPrivatePath, target: Gaia.CollectionStoragePath)
        }

        self.gaiaProvider = acct.getCapability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>(gaiaCollectionProviderPrivatePath)
        assert(self.gaiaProvider.borrow() != nil, message: "Missing or mis-typed Gaia.Collection provider")

        self.gaiaReceiver = getAccount(to).getCapability<&{Gaia.CollectionPublic}>(Gaia.CollectionPublicPath)
            .borrow()
            ?? panic("Could not borrow receiver reference")
    }

    execute {
        self.gaiaReceiver.deposit(token: <- self.gaiaProvider.borrow()!.withdraw(withdrawID: assetID))
    }
}
