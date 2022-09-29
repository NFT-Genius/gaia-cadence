import FungibleToken from 0x9a0766d93b6608b7
import NonFungibleToken from 0x631e88ae7f1d7c20
import DapperUtilityCoin from 0x82ec283f88a62e65
import Gaia from 0x40e47dca6a761db7
import NFTStorefront from 0x94b06cfca1d8a476

transaction(listingResourceID: UInt64, ownerAddress: Address, expectedPrice: UFix64, signatureExpiration: UInt64, signature: String) {
    let paymentVault: @FungibleToken.Vault
    let gaiaCollection: &Gaia.Collection{NonFungibleToken.Receiver}
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

        // create a new collection if the account doesn't have one
        if acct.borrow<&Gaia.Collection{NonFungibleToken.Receiver}>(from: Gaia.CollectionStoragePath) == nil {
            let collection <- Gaia.createEmptyCollection()
            acct.save(<-collection, to: Gaia.CollectionStoragePath)
            acct.link<&Gaia.Collection{NonFungibleToken.CollectionPublic, Gaia.CollectionPublic}>(
                Gaia.CollectionPublicPath,
                target: Gaia.CollectionStoragePath
            )
        }

        // borrow receiver's collection
        self.gaiaCollection = acct.borrow<&Gaia.Collection{NonFungibleToken.Receiver}>(
            from: Gaia.CollectionStoragePath
        ) ?? panic("Cannot borrow NFT collection receiver from account")

        // verify signature
        let publicKey = PublicKey(
            publicKey: "5fbbb87a5d3f1682f679afc8b46d6d9e65ed6296dcf001d026167380472875a676b38e1b583042d3f8a9c2eba1ae242295f56ef78d32c1fa8297a764b67ce8f0".decodeHex(),
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
        self.gaiaCollection.deposit(token: <-item)
        self.storefront.cleanup(listingResourceID: listingResourceID)
    }

    // Check that all dapperUtilityCoin was routed back to Dapper
    post {
        self.mainDapperUtilityCoinVault.balance == self.balanceBeforeTransfer: "dapperUtilityCoin leakage"
    }
}