import NFTStorefront from 0x4eb8a10cb9f87357
import DapperUtilityCoin from 0xead892083b3e2c6c
import FungibleToken from 0xf233dcee88fe0abe
import Gaia from 0x8b148183c28ff88f
// This transaction installs the Storefront ressource in an account.
transaction {
    prepare(acct: AuthAccount) {
        // Setup gaia collection if the account doesn't have one
        if acct.borrow<&Gaia.Collection>(from: Gaia.CollectionStoragePath) == nil {
            let collection <- Gaia.createEmptyCollection() as! @Gaia.Collection
            acct.save(<-collection, to: Gaia.CollectionStoragePath)
            acct.link<&{Gaia.CollectionPublic}>(Gaia.CollectionPublicPath, target: Gaia.CollectionStoragePath)
        }
        
        // If the account doesn't already have a Storefront
        if acct.borrow<&NFTStorefront.Storefront>(from: NFTStorefront.StorefrontStoragePath) == nil {
            // Create a new empty .Storefront
            let storefront <- NFTStorefront.createStorefront() as! @NFTStorefront.Storefront
            
            // save it to the account
            acct.save(<-storefront, to: NFTStorefront.StorefrontStoragePath)
            // create a public capability for the .Storefront
            acct.link<&NFTStorefront.Storefront{NFTStorefront.StorefrontPublic}>(NFTStorefront.StorefrontPublicPath, target: NFTStorefront.StorefrontStoragePath)
        }
        
        if acct.borrow<&Gaia.Collection>(from: Gaia.CollectionStoragePath) == nil {
            let collection <- Gaia.createEmptyCollection() as! @Gaia.Collection
            acct.save(<-collection, to: Gaia.CollectionStoragePath)
            acct.link<&{Gaia.CollectionPublic}>(Gaia.CollectionPublicPath, target: Gaia.CollectionStoragePath)
        }
    }
}
 