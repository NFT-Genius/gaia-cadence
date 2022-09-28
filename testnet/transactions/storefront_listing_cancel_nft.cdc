import NFTStorefront from 0x94b06cfca1d8a476

transaction(listingResourceID: UInt64, signatureExpiration: UInt64, signature: String) {
    let storefront: &NFTStorefront.Storefront{NFTStorefront.StorefrontManager}

    prepare(acct: AuthAccount) {
        self.storefront = acct.borrow<&NFTStorefront.Storefront{NFTStorefront.StorefrontManager}>(from: NFTStorefront.StorefrontStoragePath)
            ?? panic("Missing or mis-typed NFTStorefront.Storefront")

        let publicKey = PublicKey(
            publicKey: "5fbbb87a5d3f1682f679afc8b46d6d9e65ed6296dcf001d026167380472875a676b38e1b583042d3f8a9c2eba1ae242295f56ef78d32c1fa8297a764b67ce8f0".decodeHex(),
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