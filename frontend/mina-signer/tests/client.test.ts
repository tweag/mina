import Client from "../src/MinaSigner";

describe("Client Class Initialization", () => {
  it("should accept `mainnet` as a valid network parameter", () => {
    const client = new Client({ network: "mainnet" });
    expect(client).toBeDefined();
  });

  it("should accept `testnet` as a valid network parameter", () => {
    const client = new Client({ network: "testnet" });
    expect(client).toBeDefined();
  });

  it("should throw an error if a value that is not `mainnet` or `testnet` is specified", () => {
    try {
      //@ts-ignore
      new Client({ network: "new-network" });
    } catch (error) {
      expect(error).toBeDefined();
    }
  });
});
