import FungibleToken from 0x9a0766d93b6608b7
import NonFungibleToken from 0x631e88ae7f1d7c20
import FlowToken from 0x7e60df042a9c0868
import Gaia from 0x40e47dca6a761db7
import NFTStorefront from 0x94b06cfca1d8a476

// create Storefront listing that accepts Flow
// todo: implement signature

transaction(saleItemID: UInt64, saleItemPrice: UFix64) {
  let flowReceiver: Capability<&{FungibleToken.Receiver}>
  let GaiaProvider: Capability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>
  let storefront: &NFTStorefront.Storefront

  prepare(acct: AuthAccount) {

      // We need a provider capability, but one is not provided by default so we create one if needed.
      let GaiaCollectionProviderPrivatePath = /private/GaiaCollectionProviderForNFTStorefront

      self.flowReceiver = acct.getCapability<&{FungibleToken.Receiver}>(/public/flowTokenReceiver)
      assert(self.flowReceiver.borrow() != nil, message: "Missing or mis-typed FlowToken receiver")

      if !acct.getCapability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>(GaiaCollectionProviderPrivatePath)!.check() {
          acct.link<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>(GaiaCollectionProviderPrivatePath, target: Gaia.CollectionStoragePath)
      }

      self.GaiaProvider = acct.getCapability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>(GaiaCollectionProviderPrivatePath)
      assert(self.GaiaProvider.borrow() != nil, message: "Missing or mis-typed Gaia.Collection provider")

      self.storefront = acct.borrow<&NFTStorefront.Storefront>(from: NFTStorefront.StorefrontStoragePath)
          ?? panic("Missing or mis-typed NFTStorefront Storefront")
  }

  execute {
      let saleCut = NFTStorefront.SaleCut(
          receiver: self.flowReceiver,
          amount: saleItemPrice
      )
      self.storefront.createListing(
          nftProviderCapability: self.GaiaProvider,
          nftType: Type<@Gaia.NFT>(),
          nftID: saleItemID,
          salePaymentVaultType: Type<@FlowToken.Vault>(),
          saleCuts: [saleCut]
      )
   }
}