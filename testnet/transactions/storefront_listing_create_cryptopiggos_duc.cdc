import FungibleToken from 0x9a0766d93b6608b7
import NonFungibleToken from 0x631e88ae7f1d7c20
import DapperUtilityCoin from 0x82ec283f88a62e65
import CryptoPiggo from 0x57e1b27618c5bb69
import NFTStorefront from 0x94b06cfca1d8a476

transaction(saleItemID: UInt64, saleItemPrice: UFix64, cutAddresses: [Address], cutPercentages: [UFix64], signatureExpiration: UInt64, signature: String) {
    let nftProvider: Capability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>
    let storefront: &NFTStorefront.Storefront
    let oldListings: [&NFTStorefront.Listing{NFTStorefront.ListingPublic}]
    let saleCuts: [NFTStorefront.SaleCut]

    prepare(acct: AuthAccount) {
        // We need a provider capability, but one is not provided by default so we create one if needed.
        let collectionProviderPrivatePath = /private/CryptoPiggoCollectionProviderForNFTStorefront

        if !acct.getCapability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>(collectionProviderPrivatePath)!.check() {
            acct.link<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>(collectionProviderPrivatePath, target: CryptoPiggo.CollectionStoragePath)
        }

        self.nftProvider = acct.getCapability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>(collectionProviderPrivatePath)
        assert(self.nftProvider.borrow() != nil, message: "Missing or mis-typed collection provider")

        // If the account doesn't already have a Storefront
        if acct.borrow<&NFTStorefront.Storefront>(from: NFTStorefront.StorefrontStoragePath) == nil {
            // Create a new empty .Storefront
            let storefront <- NFTStorefront.createStorefront() as! @NFTStorefront.Storefront
            // save it to the account
            acct.save(<-storefront, to: NFTStorefront.StorefrontStoragePath)
            // create a public capability for the .Storefront
            acct.link<&NFTStorefront.Storefront{NFTStorefront.StorefrontPublic}>(NFTStorefront.StorefrontPublicPath, target: NFTStorefront.StorefrontStoragePath)
        }

        self.storefront = acct.borrow<&NFTStorefront.Storefront>(from: NFTStorefront.StorefrontStoragePath)
            ?? panic("Missing or mis-typed NFTStorefront Storefront")

        // validate cut percentages
        var totalPercent = 0.0
        for pct in cutPercentages {
            totalPercent = totalPercent + pct
        }
        assert(totalPercent >= 0.0 && totalPercent <= 1.0, message: "Total cut percentage must be between 0 and 1")
        assert(cutAddresses.length == cutPercentages.length, message: "Cut addresses does not match cut percentages")

        // create sale cuts
        self.saleCuts = []
        var amountRemaining = saleItemPrice
        var idx = 0
        while idx < cutAddresses.length {
            let addr = cutAddresses[idx]
            let pct = cutPercentages[idx]
            let amount = UFix64(UInt64(saleItemPrice * 100.0 * pct)) / 100.0
            let receiver = getAccount(addr).getCapability<&{FungibleToken.Receiver}>(/public/dapperUtilityCoinReceiver)
            assert(receiver.borrow() != nil, message: "Missing or mis-typed DUC receiver: ".concat(addr.toString()))
            self.saleCuts.append(NFTStorefront.SaleCut(
                receiver: receiver,
                amount: amount,
            ))
            amountRemaining = amountRemaining - amount
            idx = idx + 1
        }

        assert(amountRemaining >= 0.0, message: "Seller cut underflow")
        if (amountRemaining > 0.0) {
            // create seller cut
            let receiver = acct.getCapability<&{FungibleToken.Receiver}>(/public/dapperUtilityCoinReceiver)
            assert(receiver.borrow() != nil, message: "Missing or mis-typed seller DUC receiver")
            self.saleCuts.append(NFTStorefront.SaleCut(
                 receiver: receiver,
                 amount: amountRemaining,
             ))
        }

        let publicKey = PublicKey(
            publicKey: "5fbbb87a5d3f1682f679afc8b46d6d9e65ed6296dcf001d026167380472875a676b38e1b583042d3f8a9c2eba1ae242295f56ef78d32c1fa8297a764b67ce8f0".decodeHex(),
            signatureAlgorithm: SignatureAlgorithm.ECDSA_P256
        )

        var data = acct.address.toString()
            .concat(":")
            .concat(saleItemID.toString())
            .concat(":")
            .concat(saleItemPrice.toString())

        for addr in cutAddresses {
            data = data.concat(":").concat(addr.toString())
        }

        for pct in cutPercentages {
            data = data.concat(":").concat(pct.toString())
        }

        data = data.concat(":")
            .concat(signatureExpiration.toString())

        let isValid = publicKey.verify(
            signature: signature.decodeHex(),
            signedData: data.utf8,
            domainSeparationTag: "FLOW-V0.0-user",
            hashAlgorithm: HashAlgorithm.SHA3_256
        )

        assert(isValid, message: "Invalid signature for message: ".concat(data))
        assert(UInt64(getCurrentBlock().timestamp) <= signatureExpiration, message: "Signature expired")

        // find all existing listings with matching nft id
        self.oldListings = []
        let nftType = Type<@CryptoPiggo.NFT>()
        let listingIDs = self.storefront.getListingIDs()
        for id in listingIDs {
            let listing = self.storefront.borrowListing(listingResourceID: id)!
            if listing.getDetails().nftID == saleItemID && listing.getDetails().nftType == nftType {
                self.oldListings.append(listing)
            }
        }
    }

    execute {
        // remove old listings
        for listing in self.oldListings {
            self.storefront.removeListing(listingResourceID: listing.uuid)
        }

        self.storefront.createListing(
            nftProviderCapability: self.nftProvider,
            nftType: Type<@CryptoPiggo.NFT>(),
            nftID: saleItemID,
            salePaymentVaultType: Type<@DapperUtilityCoin.Vault>(),
            saleCuts: self.saleCuts
        )
    }
}
