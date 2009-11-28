//
// Copyright 2008 Free Software Foundation, Inc.
// 
// This file is part of GNU Radio
// 
// GNU Radio is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either asversion 3, or (at your option)
// any later version.
// 
// GNU Radio is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
// 
// You should have received a copy of the GNU General Public License
// along with GNU Radio; see the file COPYING.  If not, write to
// the Free Software Foundation, Inc., 51 Franklin Street,
// Boston, MA 02110-1301, USA.

#include <db_xcvr2450.h>
#include <db_base_impl.h>
#include <cmath>

#if 0
#define LO_OFFSET 4.25e6
#else
#define LO_OFFSET 0
#define NO_LO_OFFSET
#endif


/* ------------------------------------------------------------------------
 *  A few comments about the XCVR2450:
 *
 * It is half-duplex.  I.e., transmit and receive are mutually exclusive.
 * There is a single LO for both the Tx and Rx sides.
 * For our purposes the board is always either receiving or transmitting.
 *
 * Each board is uniquely identified by the *USRP hardware* instance and side
 * This dictionary holds a weak reference to existing board controller so it
 * can be created or retrieved as needed.
 */


/*****************************************************************************/


xcvr2450::xcvr2450(usrp_basic_sptr _usrp, int which)
  : d_weak_usrp(_usrp), d_which(which)
{
  // Handler for Tv Rx daughterboards.
  // 
  // @param usrp: instance of usrp.source_c
  // @param which: which side: 0, 1 corresponding to RX_A or RX_B respectively

  // Use MSB with no header
  d_spi_format = SPI_FMT_MSB | SPI_FMT_HDR_0;

  if(which == 0) {
    d_spi_enable = SPI_ENABLE_RX_A;
  }
  else {
    d_spi_enable = SPI_ENABLE_RX_B;
  }

  // Sane defaults
  d_mimo = 1;          // 0 = OFF, 1 = ON
  d_int_div = 192;     // 128 = min, 255 = max
  d_frac_div = 0;      // 0 = min, 65535 = max
  d_highband = 0;      // 0 = freq <= 5.4e9, 1 = freq > 5.4e9
  d_five_gig = 0;      // 0 = freq <= 3.e9, 1 = freq > 3e9
  d_cp_current = 1;    // 0 = 2mA, 1 = 4mA
  d_ref_div = 1;       // 1 to 7
  d_rssi_hbw = 0;      // 0 = 2 MHz, 1 = 6 MHz
  d_txlpf_bw = 1;      // 1 = 12 MHz, 2 = 18 MHz, 3 = 24 MHz
  d_rxlpf_bw = 1;      // 0 = 7.5 MHz, 1 = 9.5 MHz, 2 = 14 MHz, 3 = 18 MHz
  d_rxlpf_fine = 2;    // 0 = 90%, 1 = 95%, 2 = 100%, 3 = 105%, 4 = 110%
  d_rxvga_ser = 1;     // 0 = RXVGA controlled by B7:1, 1=controlled serially
  d_rssi_range = 1;    // 0 = low range (datasheet typo), 1=high range (0.5V - 2.0V) 
  d_rssi_mode = 1;     // 0 = enable follows RXHP, 1 = enabled
  d_rssi_mux = 0;      // 0 = RSSI, 1 = TEMP
  d_rx_hp_pin = 0;     // 0 = Fc set by rx_hpf, 1 = 600 KHz
  d_rx_hpf = 0;        // 0 = 100Hz, 1 = 30KHz
  d_rx_ant = 0;        // 0 = Ant. #1, 1 = Ant. #2
  d_tx_ant = 0;        // 0 = Ant. #1, 1 = Ant. #2
  d_txvga_ser = 1;     // 0 = TXVGA controlled by B6:1, 1=controlled serially
  d_tx_driver_lin = 2; // 0=50% (worst linearity), 1=63%, 2=78%, 3=100% (best lin)
  d_tx_vga_lin = 2;    // 0=50% (worst linearity), 1=63%, 2=78%, 3=100% (best lin)
  d_tx_upconv_lin = 2; // 0=50% (worst linearity), 1=63%, 2=78%, 3=100% (best lin)
  d_tx_bb_gain = 3;    // 0=maxgain-5dB, 1=max-3dB, 2=max-1.5dB, 3=max
  d_pabias_delay = 15; // 0 = 0, 15 = 7uS
  d_pabias = 0;        // 0 = 0 uA, 63 = 315uA
  d_rx_rf_gain = 0;    // 0 = 0dB, 1 = 0dB, 2 = 15dB, 3 = 30dB
  d_rx_bb_gain = 16;   // 0 = min, 31 = max (0 - 62 dB)

  d_txgain = 63;       // 0 = min, 63 = max

  // Initialize GPIO and ATR
  tx_write_io(TX_SAFE_IO, TX_OE_MASK);
  tx_write_oe(TX_OE_MASK, ~0);
  tx_set_atr_txval(TX_SAFE_IO);
  tx_set_atr_rxval(TX_SAFE_IO);
  tx_set_atr_mask(TX_OE_MASK);

  rx_write_io(RX_SAFE_IO, RX_OE_MASK);
  rx_write_oe(RX_OE_MASK, ~0);
  rx_set_atr_rxval(RX_SAFE_IO);
  rx_set_atr_txval(RX_SAFE_IO);
  rx_set_atr_mask(RX_OE_MASK);
        
  // Initialize chipset
  // TODO: perform reset sequence to ensure power up defaults
  set_reg_standby();
  set_reg_bandselpll();
  set_reg_cal();
  set_reg_lpf();
  set_reg_rxrssi_ctrl();
  set_reg_txlin_gain();
  set_reg_pabias();
  set_reg_rxgain();
  set_reg_txgain();
  //FIXME: set_freq(2.45e9);
}

xcvr2450::~xcvr2450()
{
  //printf("xcvr2450::destructor\n");
  tx_set_atr_txval(TX_SAFE_IO);
  tx_set_atr_rxval(TX_SAFE_IO);
  rx_set_atr_rxval(RX_SAFE_IO);
  rx_set_atr_txval(RX_SAFE_IO);
}

bool
xcvr2450::operator==(xcvr2450_key x)
{
  if((x.serial_no == usrp()->serial_number()) && (x.which == d_which)) {
    return true;
  }
  else {
    return false;
  }
}

void
xcvr2450::set_reg_standby()
{
  d_reg_standby = ((d_mimo<<17) | 
		   (1<<16)      | 
		   (1<<6)       | 
		   (1<<5)       | 
		   (1<<4)       | 2);
  send_reg(d_reg_standby);
}

void
xcvr2450::set_reg_int_divider()
{
  d_reg_int_divider = (((d_frac_div & 0x03)<<16) | 
		       (d_int_div<<4)            | 3);
  send_reg(d_reg_int_divider);
}

void
xcvr2450::set_reg_frac_divider()
{
  d_reg_frac_divider = ((d_frac_div & 0xfffc)<<2) | 4;
  send_reg(d_reg_frac_divider);
}
        
void
xcvr2450::set_reg_bandselpll()
{
  d_reg_bandselpll = ((d_mimo<<17)      |
		      (1<<16)           |
		      (1<<15)           |
		      (0<<11)           |
		      (d_highband<<10)  |
		      (d_cp_current<<9) |
		      (d_ref_div<<5)    |
		      (d_five_gig<<4)   | 5);
  send_reg(d_reg_bandselpll);
  d_reg_bandselpll = ((d_mimo<<17)      |
		      (1<<16)           |
		      (1<<15)           |
		      (1<<11)           |
		      (d_highband<<10)  |
		      (d_cp_current<<9) |
		      (d_ref_div<<5)    |
		      (d_five_gig<<4)   | 5);
  send_reg(d_reg_bandselpll);
}
     
void
xcvr2450::set_reg_cal()
{
  // FIXME do calibration
  d_reg_cal = (1<<14)|6;
  send_reg(d_reg_cal);
}

void
xcvr2450::set_reg_lpf()
{
  d_reg_lpf = (
	     (d_rssi_hbw<<15)  |
	     (d_txlpf_bw<<10)  |
	     (d_rxlpf_bw<<9)   |
	     (d_rxlpf_fine<<4) | 7);
  send_reg(d_reg_lpf);
}

void
xcvr2450::set_reg_rxrssi_ctrl()
{
  d_reg_rxrssi_ctrl = ((d_rxvga_ser<<16)  |
		       (d_rssi_range<<15) |
		       (d_rssi_mode<<14)  |
		       (d_rssi_mux<<12)   |
		       (1<<9)             |
		       (d_rx_hpf<<6)      |
		       (1<<4) 		  | 8);
  send_reg(d_reg_rxrssi_ctrl);
}

void
xcvr2450::set_reg_txlin_gain()
{
  d_reg_txlin_gain = ((d_txvga_ser<<14)     |
		      (d_tx_driver_lin<<12) |
		      (d_tx_vga_lin<<10)    |
		      (d_tx_upconv_lin<<6)  |
		      (d_tx_bb_gain<<4)     | 9);
  send_reg(d_reg_txlin_gain);
}

void
xcvr2450::set_reg_pabias()
{
  d_reg_pabias = (
		  (d_pabias_delay<<10) |
		  (d_pabias<<4)        | 10);
  send_reg(d_reg_pabias);
}

void
xcvr2450::set_reg_rxgain()
{
  d_reg_rxgain = (
		  (d_rx_rf_gain<<9) |
		  (d_rx_bb_gain<<4) | 11);
  send_reg(d_reg_rxgain);
}

void
xcvr2450::set_reg_txgain()
{
  d_reg_txgain = (d_txgain<<4) | 12;
  send_reg(d_reg_txgain);
}

void
xcvr2450::send_reg(int v)
{
  // Send 24 bits, it keeps last 18 clocked in
  char c[3];
  c[0] = (char)((v >> 16) & 0xff);
  c[1] = (char)((v >>  8) & 0xff);
  c[2] = (char)((v & 0xff));
  std::string s(c, 3);
  
  usrp()->_write_spi(0, d_spi_enable, d_spi_format, s);
  //printf("xcvr2450: Setting reg %d to %X\n", (v&15), v);
}

// --------------------------------------------------------------------
// These methods control the GPIO bus.  Since the board has to access
// both the io_rx_* and io_tx_* pins, we define our own methods to do so.
// This bypasses any code in db_base.
//
// The board operates in ATR mode, always.  Thus, when the board is first
// initialized, it is in receive mode, until bits show up in the TX FIFO.
//

// FIXME these should just call the similarly named common_* method on usrp_basic

bool
xcvr2450::tx_write_oe(int value, int mask)
{
  int reg;
  if(d_which)
    reg = FR_OE_2;
  else
    reg = FR_OE_0;
  return usrp()->_write_fpga_reg(reg, (mask << 16) | value);
}
   
bool
xcvr2450::tx_write_io(int value, int mask)
{
  int reg;
  if(d_which)
    reg = FR_IO_2;
  else
    reg = FR_IO_0;
  return usrp()->_write_fpga_reg(reg, (mask << 16) | value);
}

int
xcvr2450::tx_read_io()
{
  int val;
  if(d_which)
    val = FR_RB_IO_RX_B_IO_TX_B;
  else
    val = FR_RB_IO_RX_A_IO_TX_A;
  int t = usrp()->_read_fpga_reg(val);
  return t & 0xffff;
}

bool
xcvr2450::rx_write_oe(int value, int mask)
{
  int reg;
  if(d_which)
    reg = FR_OE_3;
  else
    reg = FR_OE_1;
  return usrp()->_write_fpga_reg(reg, (mask << 16) | value);
}

bool
xcvr2450::rx_write_io(int value, int mask)
{
  int reg;
  if(d_which)
    reg = FR_IO_3;
  else
    reg = FR_IO_1;
  return usrp()->_write_fpga_reg(reg, (mask << 16) | value);
}

int
xcvr2450::rx_read_io()
{
  int val;
  if(d_which)
    val = FR_RB_IO_RX_B_IO_TX_B;
  else
    val = FR_RB_IO_RX_A_IO_TX_A;
  int t = usrp()->_read_fpga_reg(val);
  return (t >> 16) & 0xffff;
}

bool
xcvr2450::tx_set_atr_mask(int v)
{
  int reg;
  if(d_which)
    reg = FR_ATR_MASK_2;
  else
    reg = FR_ATR_MASK_0;
  return usrp()->_write_fpga_reg(reg, v);
}

bool
xcvr2450::tx_set_atr_txval(int v)
{
  int reg;
  if(d_which)
    reg = FR_ATR_TXVAL_2;
  else
    reg = FR_ATR_TXVAL_0;
  return usrp()->_write_fpga_reg(reg, v);
}

bool
xcvr2450::tx_set_atr_rxval(int v)
{
  int reg;
  if(d_which)
    reg = FR_ATR_RXVAL_2;
  else
    reg = FR_ATR_RXVAL_0;
  return usrp()->_write_fpga_reg(reg, v);
}

bool
xcvr2450::rx_set_atr_mask(int v)
{
  int reg;
  if(d_which)
    reg = FR_ATR_MASK_3;
  else
    reg = FR_ATR_MASK_1;
  return usrp()->_write_fpga_reg(reg, v);
}

bool
xcvr2450::rx_set_atr_txval(int v)
{
  int reg;
  if(d_which)
    reg = FR_ATR_TXVAL_3;
  else
    reg = FR_ATR_TXVAL_1;
  return usrp()->_write_fpga_reg(reg, v);
}

bool
xcvr2450::rx_set_atr_rxval(int v)
{
  int reg;
  if(d_which)
    reg = FR_ATR_RXVAL_3;
  else
    reg = FR_ATR_RXVAL_1;
  return usrp()->_write_fpga_reg(reg, v);
}

// ----------------------------------------------------------------

void
xcvr2450::set_gpio()
{
  // We calculate four values:
  //
  // io_rx_while_rx: what to drive onto io_rx_* when receiving
  // io_rx_while_tx: what to drive onto io_rx_* when transmitting
  // io_tx_while_rx: what to drive onto io_tx_* when receiving
  // io_tx_while_tx: what to drive onto io_tx_* when transmitting
  //
  // B1-B7 is ignored as gain is set serially for now.
  
  int rx_hp, tx_antsel, rx_antsel, tx_pa_sel;
  if(d_rx_hp_pin)
    rx_hp = RX_HP;
  else
    rx_hp = 0;
  
  if(d_tx_ant)
    tx_antsel = ANTSEL_TX2_RX1;
  else
    tx_antsel = ANTSEL_TX1_RX2;

  if(d_rx_ant)
    rx_antsel = ANTSEL_TX2_RX1;
  else
    rx_antsel = ANTSEL_TX1_RX2;

  if(d_five_gig)
    tx_pa_sel = LB_PA_OFF;
  else
    tx_pa_sel = HB_PA_OFF;

  int io_rx_while_rx = EN|rx_hp|RX_EN;
  int io_rx_while_tx = EN|rx_hp;
  int io_tx_while_rx = HB_PA_OFF|LB_PA_OFF|rx_antsel|AD9515DIV;
  int io_tx_while_tx = tx_pa_sel|tx_antsel|TX_EN|AD9515DIV;
  rx_set_atr_rxval(io_rx_while_rx);
  rx_set_atr_txval(io_rx_while_tx);
  tx_set_atr_rxval(io_tx_while_rx);
  tx_set_atr_txval(io_tx_while_tx);
        
  //printf("GPIO: RXRX=%04X RXTX=%04X TXRX=%04X TXTX=%04X\n",
  //       io_rx_while_rx, io_rx_while_tx, io_tx_while_rx, io_tx_while_tx);
}
  

struct freq_result_t
xcvr2450::set_freq(double target_freq)
{
  struct freq_result_t args = {false, 0};

  double scaler;

  if(target_freq > 3e9) {
    d_five_gig = 1;
    d_ad9515_div = 3;
    scaler = 4.0/5.0;
  }
  else {
    d_five_gig = 0;
    d_ad9515_div = 3;
    scaler = 4.0/3.0;
  }

  if(target_freq > 5.408e9) {
    d_highband = 1;
  }
  else {
    d_highband = 0;
  }

  double vco_freq = target_freq*scaler;
  double sys_clk = usrp()->fpga_master_clock_freq();  // Usually 64e6 
  double ref_clk = sys_clk / d_ad9515_div;
        
  double phdet_freq = ref_clk/d_ref_div;
  double div = vco_freq/phdet_freq;
  d_int_div = int(floor(div));
  d_frac_div = int((div-d_int_div)*65536.0);
  double actual_freq = phdet_freq*(d_int_div+(d_frac_div/65536.0))/scaler;
  
  //printf("RF=%f VCO=%f R=%d PHD=%f DIV=%3.5f I=%3d F=%5d ACT=%f\n",
  //	 target_freq, vco_freq, d_ref_div, phdet_freq,
  //	 div, d_int_div, d_frac_div, actual_freq);

  set_gpio();
  set_reg_int_divider();
  set_reg_frac_divider();
  set_reg_bandselpll();

  args.ok = lock_detect();
#ifdef NO_LO_OFFSET
  args.baseband_freq = target_freq;
#else
  args.baseband_freq = actual_freq;
#endif

  if(!args.ok){
    printf("Fail %f\n", target_freq);
  }
  return args;
}

bool
xcvr2450::lock_detect()
{
  /*
    @returns: the value of the VCO/PLL lock detect bit.
    @rtype: 0 or 1
  */
  if(rx_read_io() & LOCKDET) {
    return true;
  }
  else {      // Give it a second chance
    if(rx_read_io() & LOCKDET)
      return true;
    else
      return false;
  }
}

bool
xcvr2450::set_rx_gain(float gain)
{
  if(gain < 0.0) 
    gain = 0.0;
  if(gain > 92.0)
    gain = 92.0;

  // Split the gain between RF and baseband
  // This is experimental, not prescribed
  if(gain < 31.0) {
    d_rx_rf_gain = 0;		           // 0 dB RF gain
    rx_bb_gain = int(gain/2.0);
  }
  
  if(gain >= 30.0 and gain < 60.5) {
    d_rx_rf_gain = 2;                    // 15 dB RF gain
    d_rx_bb_gain = int((gain-15.0)/2.0);
  }
  
  if(gain >= 60.5) {
    d_rx_rf_gain = 3;			   // 30.5 dB RF gain
    d_rx_bb_gain = int((gain-30.5)/2.0);
  }
  
  set_reg_rxgain();
  
  return true;
}

bool
xcvr2450::set_tx_gain(float gain)
{
  if(gain < 0.0) {
    gain = 0.0;
  }
  if(gain > 30.0) {
    gain = 30.0;
  }
  
  d_txgain = int((gain/30.0)*63);
  set_reg_txgain();

  return true;
}


/*****************************************************************************/


//_xcvr2450_inst = weakref.WeakValueDictionary()
std::vector<xcvr2450_sptr> _xcvr2450_inst;

xcvr2450_sptr
_get_or_make_xcvr2450(usrp_basic_sptr usrp, int which)
{
  xcvr2450_sptr inst;
  xcvr2450_key key = {usrp->serial_number(), which};
  std::vector<xcvr2450_sptr>::iterator itr; // =
  //std::find(_xcvr2450_inst.begin(), _xcvr2450_inst.end(), key);

  for(itr = _xcvr2450_inst.begin(); itr != _xcvr2450_inst.end(); itr++) {
    if(*(*itr) == key) {
      //printf("Using existing xcvr2450 instance\n");
      inst = *itr;
      break;
    }
  }
  
  if(itr == _xcvr2450_inst.end()) {
    //printf("Creating new xcvr2450 instance\n");
    inst = xcvr2450_sptr(new xcvr2450(usrp, which));
    _xcvr2450_inst.push_back(inst);
  }

  return inst;
}


/*****************************************************************************/


db_xcvr2450_base::db_xcvr2450_base(usrp_basic_sptr usrp, int which)
  : db_base(usrp, which)
{
  /*
   * Abstract base class for all xcvr2450 boards.
   * 
   * Derive board specific subclasses from db_xcvr2450_base_{tx,rx}
   *
   * @param usrp: instance of usrp.source_c
   * @param which: which side: 0 or 1 corresponding to side A or B respectively
   * @type which: int
   */
  
  d_xcvr = _get_or_make_xcvr2450(usrp, which);
}

db_xcvr2450_base::~db_xcvr2450_base()
{
}

struct freq_result_t
db_xcvr2450_base::set_freq(double target_freq)
{
  /*
   * @returns (ok, actual_baseband_freq) where:
   * ok is True or False and indicates success or failure,
   * actual_baseband_freq is the RF frequency that corresponds to DC in the IF.
   */
  return d_xcvr->set_freq(target_freq+d_lo_offset);
}

bool
db_xcvr2450_base::is_quadrature()
{
  /*
   * Return True if this board requires both I & Q analog channels.
   *
   * This bit of info is useful when setting up the USRP Rx mux register.
   */
   return true;
}

double
db_xcvr2450_base::freq_min()
{
  return 2.4e9;
}

double
db_xcvr2450_base::freq_max()
{
  return 6.0e9;
}


/******************************************************************************/


db_xcvr2450_tx::db_xcvr2450_tx(usrp_basic_sptr usrp, int which)
  : db_xcvr2450_base(usrp, which)
{
  set_lo_offset(LO_OFFSET);
  //printf("db_xcvr2450_tx::db_xcvr2450_tx\n");
}

db_xcvr2450_tx::~db_xcvr2450_tx()
{
}

float
db_xcvr2450_tx::gain_min()
{
  return 0;
}

float
db_xcvr2450_tx::gain_max()
{
  return 30;
}

float
db_xcvr2450_tx::gain_db_per_step()
{
  return (30.0/63.0);
}

bool
db_xcvr2450_tx::set_gain(float gain)
{
  return d_xcvr->set_tx_gain(gain);
}

bool
db_xcvr2450_tx::i_and_q_swapped()
{
  return true;
}


/******************************************************************************/


db_xcvr2450_rx::db_xcvr2450_rx(usrp_basic_sptr usrp, int which)
  : db_xcvr2450_base(usrp, which)
{
  /*
   * @param usrp: instance of usrp.source_c
   * @param which: 0 or 1 corresponding to side RX_A or RX_B respectively.
   */
  set_lo_offset(LO_OFFSET);
  //printf("db_xcvr2450_rx:d_xcvr_2450_rx\n");
}

db_xcvr2450_rx::~db_xcvr2450_rx()
{
}

float
db_xcvr2450_rx::gain_min()
{
  return 0.0;
}

float
db_xcvr2450_rx::gain_max()
{
  return 92.0;
}

float
db_xcvr2450_rx::gain_db_per_step()
{
  return 1;
}

bool
db_xcvr2450_rx::set_gain(float gain)
{
  return d_xcvr->set_rx_gain(gain);
}
