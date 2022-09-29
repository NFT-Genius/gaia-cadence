import FungibleToken from 0x9a0766d93b6608b7
import NonFungibleToken from 0x631e88ae7f1d7c20
import MetadataViews from 0x631e88ae7f1d7c20
import NFTStorefront from 0x94b06cfca1d8a476
import FlowUtilityToken from 0x82ec283f88a62e65
import TopShot from 0x877931736ee77cff

transaction(storefrontAddress: Address, listingResourceID: UInt64, expectedPrice: UFix64, signatureExpiration: UInt64, signature: String, imageURL: String) {
    let paymentVault: @FungibleToken.Vault
    let nftCollection: &TopShot.Collection{NonFungibleToken.Receiver}
    let storefront: &NFTStorefront.Storefront{NFTStorefront.StorefrontPublic}
    let listing: &NFTStorefront.Listing{NFTStorefront.ListingPublic}
    let salePrice: UFix64
    let balanceBeforeTransfer: UFix64
    let mainFlowUtilityTokenVault: &FlowUtilityToken.Vault

    prepare(dapper: AuthAccount, buyer: AuthAccount) {
        let MomentCollectionPublicPath = /public/MomentCollection
        let MomentCollectionStoragePath = /storage/MomentCollection

        // Initialize the collection if the buyer does not already have one
        if buyer.borrow<&TopShot.Collection>(from: MomentCollectionStoragePath) == nil {
            let collection <- TopShot.createEmptyCollection() as! @TopShot.Collection
            buyer.save(<-collection, to: MomentCollectionStoragePath)
            buyer.link<&TopShot.Collection{NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection}>(
                MomentCollectionPublicPath,
                target: MomentCollectionStoragePath
            )
            ?? panic("Could not link collection Pub Path")
        }

        // Get the storefront reference from the seller
        self.storefront = getAccount(storefrontAddress)
            .getCapability<&NFTStorefront.Storefront{NFTStorefront.StorefrontPublic}>(
                NFTStorefront.StorefrontPublicPath
            )!
            .borrow()
            ?? panic("Could not borrow Storefront from provided address")

        // Get the listing by ID from the storefront
        self.listing = self.storefront.borrowListing(listingResourceID: listingResourceID)
            ?? panic("No Offer with that ID in Storefront")
        self.salePrice = self.listing.getDetails().salePrice

        // Get a DUC vault from Dapper's account
        self.mainFlowUtilityTokenVault = dapper.borrow<&FlowUtilityToken.Vault>(from: /storage/flowUtilityTokenVault)
            ?? panic("Cannot borrow FlowUtilityToken vault from account storage")
        self.balanceBeforeTransfer = self.mainFlowUtilityTokenVault.balance
        self.paymentVault <- self.mainFlowUtilityTokenVault.withdraw(amount: self.salePrice)

        // Get the collection from the buyer so the NFT can be deposited into it
        self.nftCollection = buyer.borrow<&TopShot.Collection{NonFungibleToken.Receiver}>(
            from: MomentCollectionStoragePath
        ) ?? panic("Cannot borrow NFT collection receiver from account")

        // verify signature
        let publicKey = PublicKey(
            publicKey: "5fbbb87a5d3f1682f679afc8b46d6d9e65ed6296dcf001d026167380472875a676b38e1b583042d3f8a9c2eba1ae242295f56ef78d32c1fa8297a764b67ce8f0".decodeHex(),
            signatureAlgorithm: SignatureAlgorithm.ECDSA_P256
        )

        let data = storefrontAddress.toString()
            .concat(":")
            .concat(listingResourceID.toString())
            .concat(":")
            .concat(expectedPrice.toString())
            .concat(":")
            .concat(signatureExpiration.toString())

        let isValid = publicKey.verify(
            signature: signature.decodeHex(),
            signedData: data.utf8,
            domainSeparationTag: "FLOW-V0.0-user",
            hashAlgorithm: HashAlgorithm.SHA3_256
        )

        assert(isValid, message: "Invalid signature for message: ".concat(data))
        assert(UInt64(getCurrentBlock().timestamp) <= signatureExpiration, message: "Signature expired")
    }

    // Check that the price is right
    pre {
        self.salePrice == expectedPrice: "unexpected price"
    }

    execute {
        let item <- self.listing.purchase(
            payment: <-self.paymentVault
        )

        self.nftCollection.deposit(token: <-item)

        // Remove listing-related information from the storefront since the listing has been purchased.
        self.storefront.cleanup(listingResourceID: listingResourceID)
    }

    // Check that all flowUtilityToken was routed back to Dapper
    post {
        self.mainFlowUtilityTokenVault.balance == self.balanceBeforeTransfer: "FlowUtilityToken leakage"
    }
}
