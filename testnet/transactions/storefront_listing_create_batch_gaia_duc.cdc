import FungibleToken from 0x9a0766d93b6608b7
import NonFungibleToken from 0x631e88ae7f1d7c20
import DapperUtilityCoin from 0x82ec283f88a62e65
import Gaia from 0x40e47dca6a761db7
import NFTStorefront from 0x94b06cfca1d8a476

// Batch create listings. Specified cuts are applied to *all* new listings.

transaction(
    saleItemIDs: [UInt64],
    saleItemPrices: [UFix64],
    cutAddresses: [Address],
    cutPercentages: [UFix64],
    signatureExpiration: UInt64,
    signature: String
) {
    let sellerNFTProvider: Capability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>
    let storefront: &NFTStorefront.Storefront
    let saleCuts: [[NFTStorefront.SaleCut]]

    prepare(acct: AuthAccount) {
        pre {
            saleItemPrices.length == saleItemIDs.length: "sale item prices length mismatch"
            cutAddresses.length == cutPercentages.length: "cut addresses/percentages length mismatch"
        }

        let publicKey = PublicKey(
            publicKey: "5fbbb87a5d3f1682f679afc8b46d6d9e65ed6296dcf001d026167380472875a676b38e1b583042d3f8a9c2eba1ae242295f56ef78d32c1fa8297a764b67ce8f0".decodeHex(),
            signatureAlgorithm: SignatureAlgorithm.ECDSA_P256
        )

        var data = acct.address.toString()

        for id in saleItemIDs {
            data = data.concat(":").concat(id.toString())
        }

        for price in saleItemPrices {
            data = data.concat(":").concat(price.toString())
        }

        for addr in cutAddresses {
            data = data.concat(":").concat(addr.toString())
        }

        for pct in cutPercentages {
            data = data.concat(":").concat(pct.toString())
        }

        data = data.concat(":")
            .concat(signatureExpiration.toString())

        // check if signed message is valid
        let isValid = publicKey.verify(
            signature: signature.decodeHex(),
            signedData: data.utf8,
            domainSeparationTag: "FLOW-V0.0-user",
            hashAlgorithm: HashAlgorithm.SHA3_256
        )

        assert(isValid, message: "Invalid signature for message: ".concat(data))
        assert(UInt64(getCurrentBlock().timestamp) <= signatureExpiration, message: "Signature expired")

        // create gaia storefront provider if needed
        let gaiaCollectionProviderPrivatePath = /private/GaiaCollectionProviderForNFTStorefront
        if !acct.getCapability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>(gaiaCollectionProviderPrivatePath).check() {
            acct.link<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>(gaiaCollectionProviderPrivatePath, target: Gaia.CollectionStoragePath)
        }

        // get seller nft provider
        self.sellerNFTProvider = acct.getCapability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>(gaiaCollectionProviderPrivatePath)
        assert(self.sellerNFTProvider.borrow() != nil, message: "Missing or mis-typed Gaia.Collection provider")

        // create seller storefront if needed
        if acct.borrow<&NFTStorefront.Storefront>(from: NFTStorefront.StorefrontStoragePath) == nil {
            // Create a new empty .Storefront
            let storefront <- NFTStorefront.createStorefront()
            // save it to the account
            acct.save(<-storefront, to: NFTStorefront.StorefrontStoragePath)
            // create a public capability for the .Storefront
            acct.link<&NFTStorefront.Storefront{NFTStorefront.StorefrontPublic}>(NFTStorefront.StorefrontPublicPath, target: NFTStorefront.StorefrontStoragePath)
        }

        // get seller storefront
        self.storefront = acct.borrow<&NFTStorefront.Storefront>(from: NFTStorefront.StorefrontStoragePath)
            ?? panic("Missing or mis-typed NFTStorefront Storefront")

        // get seller fungible token receiver
        let sellerFTReceiver = acct.getCapability<&{FungibleToken.Receiver}>(/public/dapperUtilityCoinReceiver)
        assert(sellerFTReceiver.borrow() != nil, message: "Missing or mis-typed seller DUC receiver")

        // create sale cuts for each item based on price
        self.saleCuts = []
        var i = 0
        while i < saleItemIDs.length {
            let price = saleItemPrices[i]
            let cuts: [NFTStorefront.SaleCut] = []

            // validate cut percentages
            var totalPercent = 0.0
            for pct in cutPercentages {
                totalPercent = totalPercent + pct
            }
            assert(totalPercent >= 0.0 && totalPercent <= 1.0, message: "Total cut percentage must be between 0 and 1")
            assert(cutAddresses.length == cutPercentages.length, message: "Cut addresses does not match cut percentages")

            // create sale cuts
            var amountRemaining = price
            var idx = 0
            while idx < cutAddresses.length {
                let addr = cutAddresses[idx]
                let pct = cutPercentages[idx]
                let amount = UFix64(UInt64(price * 100.0 * pct)) / 100.0
                let cutReceiver = getAccount(addr).getCapability<&{FungibleToken.Receiver}>(/public/dapperUtilityCoinReceiver)
                assert(cutReceiver.borrow() != nil, message: "Missing or mis-typed DUC receiver: ".concat(addr.toString()))
                cuts.append(NFTStorefront.SaleCut(
                    receiver: cutReceiver,
                    amount: amount,
                ))
                amountRemaining = amountRemaining - amount
                idx = idx + 1
            }

            assert(amountRemaining >= 0.0, message: "Seller cut underflow")
            if (amountRemaining > 0.0) {
                // create seller cut
                cuts.append(NFTStorefront.SaleCut(
                    receiver: sellerFTReceiver,
                    amount: amountRemaining,
                ))
            }

            self.saleCuts.append(cuts)

            i = i + 1
        }
    }

    execute {
        // create listings
        for i, itemID in saleItemIDs {
            self.storefront.createListing(
                nftProviderCapability: self.sellerNFTProvider,
                nftType: Type<@Gaia.NFT>(),
                nftID: itemID,
                salePaymentVaultType: Type<@DapperUtilityCoin.Vault>(),
                saleCuts: self.saleCuts[i]
            )
        }
    }
}