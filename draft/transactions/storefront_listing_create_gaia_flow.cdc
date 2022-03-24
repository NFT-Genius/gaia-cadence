import FungibleToken from 0xFungibleToken
import NonFungibleToken from 0xNonFungibleToken 
import FlowToken from 0xFlowToken
import Gaia from 0xGaia
import NFTStorefront from 0xNFTStorefront

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