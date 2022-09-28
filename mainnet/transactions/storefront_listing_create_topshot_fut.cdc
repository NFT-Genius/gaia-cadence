import FungibleToken from 0xf233dcee88fe0abe
import NonFungibleToken from 0x1d7e57aa55817448
import FlowUtilityToken from 0xead892083b3e2c6c
import NFTStorefront from 0x4eb8a10cb9f87357
import TopShot from 0x0b2a3299cc857e29
import TokenForwarding from 0xe544175ee0461c4b

transaction(saleItemID: UInt64, saleItemPrice: UFix64, cutAddresses: [Address], cutPercentages: [UFix64], signatureExpiration: UInt64, signature: String) {
    let nftProvider: Capability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>
    let storefront: &NFTStorefront.Storefront
    let saleCuts: [NFTStorefront.SaleCut]

    prepare(acct: AuthAccount) {
        let futDapperAddress: Address = 0xead892083b3e2c6c

        // We need a provider capability, but one is not provided by default so we create one if needed.
        let CollectionProviderPrivatePath = /private/TopShotCollectionProviderForNFTStorefront
        let MomentCollectionStoragePath = /storage/MomentCollection

        if !acct.getCapability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>(CollectionProviderPrivatePath)!.check() {
            acct.link<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>(CollectionProviderPrivatePath, target: MomentCollectionStoragePath)
        }

        self.nftProvider = acct.getCapability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>(CollectionProviderPrivatePath)
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

        // FUT Setup if the user's account is not initialized with FUT receiver
        if acct.borrow<&{FungibleToken.Receiver}>(from: /storage/flowUtilityTokenReceiver) == nil {
            let dapper = getAccount(futDapperAddress)
            let dapperFUTReceiver = dapper.getCapability<&{FungibleToken.Receiver}>(/public/flowUtilityTokenReceiver)!

            // Create a new Forwarder resource for FUT and store it in the new account's storage
            let futForwarder <- TokenForwarding.createNewForwarder(recipient: dapperFUTReceiver)
            acct.save(<-futForwarder, to: /storage/flowUtilityTokenReceiver)

            // Publish a Receiver capability for the new account, which is linked to the FUT Forwarder
            acct.link<&FlowUtilityToken.Vault{FungibleToken.Receiver}>(
                /public/flowUtilityTokenReceiver,
                target: /storage/flowUtilityTokenReceiver
            )
        }

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
            let amount = saleItemPrice * pct
            let receiver = getAccount(addr).getCapability<&{FungibleToken.Receiver}>(/public/flowUtilityTokenReceiver)
            assert(receiver.check(), message: "Missing or mis-typed FUT receiver: ".concat(addr.toString()))
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
            let receiver = acct.getCapability<&{FungibleToken.Receiver}>(/public/flowUtilityTokenReceiver)
            assert(receiver.borrow() != nil, message: "Missing or mis-typed seller FUT receiver")
            self.saleCuts.append(NFTStorefront.SaleCut(
                 receiver: receiver,
                 amount: amountRemaining,
             ))
        }

        let publicKey = PublicKey(
            publicKey: "dddd52da46af51203d5101de0214c2f0a22d97bcc0c824f6a2dfe91baa4e94465d2f9ffd8180d84fcfa72dc78cdebe3842a7b1a843e76444d81bdbf77ff29be1".decodeHex(),
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
    }

    execute {
        self.storefront.createListing(
            nftProviderCapability: self.nftProvider,
            nftType: Type<@TopShot.NFT>(),
            nftID: saleItemID,
            salePaymentVaultType: Type<@FlowUtilityToken.Vault>(),
            saleCuts: self.saleCuts
        )
    }
}