import NFTStorefront from 0x4eb8a10cb9f87357

transaction(listingResourceID: UInt64, signatureExpiration: UInt64, signature: String) {
    let storefront: &NFTStorefront.Storefront{NFTStorefront.StorefrontManager}

    prepare(acct: AuthAccount) {
        self.storefront = acct.borrow<&NFTStorefront.Storefront{NFTStorefront.StorefrontManager}>(from: NFTStorefront.StorefrontStoragePath)
            ?? panic("Missing or mis-typed NFTStorefront.Storefront")

        let publicKey = PublicKey(
            publicKey: "dddd52da46af51203d5101de0214c2f0a22d97bcc0c824f6a2dfe91baa4e94465d2f9ffd8180d84fcfa72dc78cdebe3842a7b1a843e76444d81bdbf77ff29be1".decodeHex(),
            signatureAlgorithm: SignatureAlgorithm.ECDSA_P256
        )

        let data = acct.address.toString()
            .concat(":")
            .concat(listingResourceID.toString())

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
        self.storefront.removeListing(listingResourceID: listingResourceID)
    }
}
