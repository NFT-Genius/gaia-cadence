import GaiaPrimarySale from 0x8cd1880bb292c236

pub struct PurchaseData {
    pub let id: UInt64
    pub let name: String?
    pub let amount: UFix64
    pub let description: String?
    pub let imageURL: String?

    init(id: UInt64, name: String?, amount: UFix64, description: String?, imageURL: String?) {
        self.id = id
        self.name = name
        self.amount = amount
        self.description = description
        self.imageURL = imageURL
    }
}

pub fun main(
    marketplaceAddress: Address,
    primarySaleAddress: Address,
    primarySaleExternalID: String,
    assetIDs: [UInt64],
    priceType: String,
    expectedPrice: UFix64,
    sigExpiration: UInt64,
    sig: String
): PurchaseData {
    let account = getAccount(primarySaleAddress)

    let primarySaleRef = account
        .getCapability<&{GaiaPrimarySale.PrimarySalePublic}>(
            GaiaPrimarySale.PrimarySalePublicPath
        )
        .borrow()
        ?? panic("Could not borrow primary sale from address")

    let primarySaleDetails = primarySaleRef.getDetails()

    return PurchaseData(
        id: 0,
        name: primarySaleDetails.name,
        amount: expectedPrice,
        description: primarySaleDetails.description,
        imageURL: primarySaleDetails.imageURI,
    )
}
