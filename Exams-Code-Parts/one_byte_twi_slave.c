#define TW_START 0x08
#define TW_MT_SLA_ACK 0x18
#define TW_MT_DATA_ACK 0x28
#define TW_STATUS_MASK 0xF8

// Send START condition
TWCR0 = (1<<TWINT) | (1<<TWSTA) | (1<<TWEN);

// Wait for TWINT flag
while (!(TWCR0 & (1<<TWINT)));

// Check START status
if ((TWSR0 & TW_STATUS_MASK) != TW_START) {
    ERROR();
}

// Send slave address + write
TWDR0 = SLA_W;
TWCR0 = (1<<TWINT) | (1<<TWEN);

// Wait for TWINT flag
while (!(TWCR0 & (1<<TWINT)));

// Check slave address acknowledgment
if ((TWSR0 & TW_STATUS_MASK) != TW_MT_SLA_ACK) {
    ERROR();
}

// Send data
TWDR0 = DATA;
TWCR0 = (1<<TWINT) | (1<<TWEN);

// Wait for TWINT flag
while (!(TWCR0 & (1<<TWINT)));

// Check data acknowledgment
if ((TWSR0 & TW_STATUS_MASK) != TW_MT_DATA_ACK) {
    ERROR();
}

// Send STOP condition
TWCR0 = (1<<TWINT) | (1<<TWEN) | (1<<TWSTO);

// TWCR0 = (1<<TWINT) | (1<<TWSTA) | (1<<TWEN);

// while (!(TWCR0 & (1<<TWINT)));

// if ((TWSR0 & 0xF8) !=START){
//     ERROR();
// };

// TWDR0 = SLA_W;
// TWCR0 = (1<<TWINT) | (1<<TWEN);

// while (!(TWCR0 & (1<<TWINT)));

// if ((TWSR0 & 0xF8) != MT_SLA_ACK){ 
//     ERROR();
//      }

// TWDR0 = DATA;
// TWCR0 = (1<<TWINT) | (1<<TWEN);

// while (!(TWCR0 & (1<<TWINT)));

// if ((TWSR0 & 0xF8) != MT_DATA_ACK){ ERROR() };

// TWCR0 = (1<<TWINT)| (1<<TWEN) | (1<<TWSTO); 