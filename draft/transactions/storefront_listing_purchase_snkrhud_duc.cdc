import FungibleToken from 0xFungibleToken
import NonFungibleToken from 0xNonFungibleToken
import DapperUtilityCoin from 0xDapperUtilityCoin
import SNKRHUDNFT from 0xSNKRHUDNFT
import NFTStorefront from 0xNFTStorefront
import MetadataViews from 0xMetadataViews

transaction(listingResourceID: UInt64, ownerAddress: Address, expectedPrice: UFix64, signatureExpiration: UInt64, signature: String) {
    let paymentVault: @FungibleToken.Vault
    let nftCollection: &SNKRHUDNFT.Collection{NonFungibleToken.Receiver}
    let storefront: &NFTStorefront.Storefront{NFTStorefront.StorefrontPublic}
    let listing: &NFTStorefront.Listing{NFTStorefront.ListingPublic}
    let mainDapperUtilityCoinVault: &DapperUtilityCoin.Vault
    let balanceBeforeTransfer: UFix64

    prepare(dapper: AuthAccount, acct: AuthAccount) {
        // borrow seller's storefront reference
        self.storefront = getAccount(ownerAddress)
            .getCapability<&NFTStorefront.Storefront{NFTStorefront.StorefrontPublic}>(
                NFTStorefront.StorefrontPublicPath
            )!
            .borrow()
            ?? panic("Could not borrow Storefront from provided address")

        // borrow storefront listing
        self.listing = self.storefront.borrowListing(listingResourceID: listingResourceID)
                    ?? panic("No Offer with that ID in Storefront")

        let price = self.listing.getDetails().salePrice
        assert(expectedPrice == price, message: "Actual price does not match expected: ".concat(price.toString()))

        // Withdraw mainDapperUtilityCoinVault from Dapper's account
        self.mainDapperUtilityCoinVault = dapper.borrow<&DapperUtilityCoin.Vault>(from: /storage/dapperUtilityCoinVault)
            ?? panic("Cannot borrow DapperUtilityCoin vault from account storage")
        self.balanceBeforeTransfer = self.mainDapperUtilityCoinVault.balance
        self.paymentVault <- self.mainDapperUtilityCoinVault.withdraw(amount: price)


        // create a new NFT collection if the account doesn't have one
        if acct.borrow<&SNKRHUDNFT.Collection>(from: SNKRHUDNFT.CollectionStoragePath) == nil {
            let collection <- SNKRHUDNFT.createEmptyCollection() as! @SNKRHUDNFT.Collection
            acct.save(<-collection, to: SNKRHUDNFT.CollectionStoragePath)
            acct.link<&{NonFungibleToken.CollectionPublic, SNKRHUDNFT.CollectionPublic, MetadataViews.ResolverCollection}>
                (SNKRHUDNFT.CollectionPublicPath, target: SNKRHUDNFT.CollectionStoragePath)
        }

        // borrow receiver's collection
        self.nftCollection = acct.borrow<&SNKRHUDNFT.Collection{NonFungibleToken.Receiver}>(
            from: SNKRHUDNFT.CollectionStoragePath
        ) ?? panic("Cannot borrow NFT collection receiver from account")

        // verify signature
        let publicKey = PublicKey(
            publicKey: "dddd52da46af51203d5101de0214c2f0a22d97bcc0c824f6a2dfe91baa4e94465d2f9ffd8180d84fcfa72dc78cdebe3842a7b1a843e76444d81bdbf77ff29be1".decodeHex(),
            signatureAlgorithm: SignatureAlgorithm.ECDSA_P256
        )

        let data = acct.address.toString()
            .concat(":")
            .concat(ownerAddress.toString())
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

    execute {
        // purchase listing
        let item <- self.listing.purchase(
            payment: <-self.paymentVault
        )

        // deposit to buyer's collection and clean up storefront
        self.nftCollection.deposit(token: <-item)
        self.storefront.cleanup(listingResourceID: listingResourceID)
    }

    // Check that all dapperUtilityCoin was routed back to Dapper
    post {
        self.mainDapperUtilityCoinVault.balance == self.balanceBeforeTransfer: "dapperUtilityCoin leakage"
    }
}
