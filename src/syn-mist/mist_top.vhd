-------------------------------------------------------------------------------
--
-- MSX1 FPGA project
--
-- Copyright (c) 2016, Fabio Belavenuto (belavenuto@gmail.com)
--
-- All rights reserved
--
-- Redistribution and use in source and synthezised forms, with or without
-- modification, are permitted provided that the following conditions are met:
--
-- Redistributions of source code must retain the above copyright notice,
-- this list of conditions and the following disclaimer.
--
-- Redistributions in synthesized form must reproduce the above copyright
-- notice, this list of conditions and the following disclaimer in the
-- documentation and/or other materials provided with the distribution.
--
-- Neither the name of the author nor the names of other contributors may
-- be used to endorse or promote products derived from this software without
-- specific prior written permission.
--
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
-- AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
-- THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
-- PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE
-- LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
-- CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
-- SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
-- INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
-- CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
-- ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
-- POSSIBILITY OF SUCH DAMAGE.
--
-- Please report bugs to the author, but before you do so, please
-- make sure that this is not a derivative work and that
-- you have the latest version of this file.
--
-------------------------------------------------------------------------------
--
-- MIST top-level
--

-- altera message_off 10540 10541

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Generic top-level entity for MIST board
entity mist_top is
	generic (
		per_jt51_g				: boolean		:= false
	);
	port (
		-- Clocks
		clk27_i			: in    std_logic_vector( 1 downto 0);
		-- LED
		led_n_o			: out   std_logic									:= '0';
		-- Serial
		uart_rx_i		: in    std_logic;
		uart_tx_o		: out   std_logic									:= '0';
		-- SDRAM
		sdram_cke_o		: out   std_logic									:= '1';
		sdram_clk_o		: out   std_logic									:= '1';
		sdram_addr_o	: out   std_logic_vector(12 downto 0)		:= (others => '0');
		sdram_data_io	: inout std_logic_vector(15 downto 0)		:= (others => '0');
		sdram_cas_n_o	: out   std_logic									:= '1';
		sdram_ras_n_o	: out   std_logic									:= '1';
		sdram_cs_n_o	: out   std_logic									:= '1';
		sdram_we_n_o	: out   std_logic									:= '1';
		sdram_ba_o		: out   std_logic_vector( 1 downto 0)		:= "11";
		sdram_ldqm_o	: out   std_logic									:= '1';
		sdram_udqm_o	: out   std_logic									:= '1';
		-- SPI
		spi_do_io		: inout std_logic									:= '1';
		spi_di_i			: in    std_logic;
		spi_sck_i		: in    std_logic;
		conf_data0_i	: in    std_logic;															-- SPI_SS for user_io
		spi_ss2_i		: in    std_logic;															-- FPGA
		spi_ss3_i		: in    std_logic;															-- OSD
		spi_ss4_i		: in    std_logic;															-- "sniff" mode
		-- Audio
		audio_l_o		: out   std_logic									:= '0';
		audio_r_o		: out   std_logic									:= '0';
		-- VGA
		vga_r_o			: out   std_logic_vector( 5 downto 0)		:= (others => '0');
		vga_g_o			: out   std_logic_vector( 5 downto 0)		:= (others => '0');
		vga_b_o			: out   std_logic_vector( 5 downto 0)		:= (others => '0');
		vga_hsync_n_o	: out   std_logic									:= '1';
		vga_vsync_n_o	: out   std_logic									:= '1'
	);
end entity;

architecture behavior of mist_top is

	constant CONF_STR : string := "MSX1;;T1,Reset";

	function to_slv(s: string) return std_logic_vector is
		constant ss: string(1 to s'length) := s;
		variable rval: std_logic_vector(1 to 8 * s'length);
		variable p: integer;
		variable c: integer;
	begin
		for i in ss'range loop
			p := 8 * i;
			c := character'pos(ss(i));
			rval(p - 7 to p) := std_logic_vector(to_unsigned(c,8));
		end loop;
		return rval;
	end function;

	component user_io
	generic (
		STRLEN : integer := 0
	);
	port (
		conf_str					: in  std_logic_vector(8*STRLEN-1 downto 0);
		SPI_SCK					: in  std_logic;
		CONF_DATA0				: in  std_logic;
		SPI_DI					: in  std_logic;
		SPI_DO	 				: out std_logic;
		joystick_0				: out std_logic_vector( 7 downto 0);
		joystick_1				: out std_logic_vector( 7 downto 0);
		joystick_analog_0		: out std_logic_vector(15 downto 0);
		joystick_analog_1		: out std_logic_vector(15 downto 0);
		buttons					: out std_logic_vector( 1 downto 0);
		switches					: out std_logic_vector( 1 downto 0);
		scandoubler_disable	: out std_logic;
		status					: out std_logic_vector( 7 downto 0);
		-- SD Card Emulation
		sd_lba					: in  std_logic_vector(31 downto 0);
		sd_rd						: in  std_logic;
		sd_wr						: in  std_logic;
		sd_ack					: out std_logic;
		sd_conf					: in  std_logic;
		sd_sdhc					: in  std_logic;
		sd_dout					: out std_logic_vector( 7 downto 0);
		sd_dout_strobe			: out std_logic;
		sd_din					: in  std_logic_vector( 7 downto 0);
		sd_din_strobe			: out std_logic;
		sd_mounted				: out std_logic;
		-- ps2 keyboard emulation
		ps2_clk					: in  std_logic;
		ps2_kbd_clk				: out std_logic;
		ps2_kbd_data			: out std_logic;
		ps2_mouse_clk			: out std_logic;
		ps2_mouse_data			: out std_logic;
		-- serial com port 
		serial_data				: in  std_logic_vector( 7 downto 0);
		serial_strobe			: in  std_logic
	);
	end component user_io;

	component osd
	port (
		pclk, sck, ss, sdi, hs_in, vs_in	: in  std_logic;
		red_in, blue_in, green_in			: in  std_logic_vector(5 downto 0);
		red_out, blue_out, green_out		: out std_logic_vector(5 downto 0);
		osd_enable								: out std_logic
	);
	end component osd;

	component sd_card
	port (
		io_lba			: out std_logic_vector(31 downto 0);
		io_rd				: out std_logic;
		io_wr				: out std_logic;
		io_ack			: in  std_logic;
		io_sdhc			: out std_logic;
		io_conf			: out std_logic;
		io_din			: in  std_logic_vector(7 downto 0);
		io_din_strobe	: in  std_logic;
		io_dout			: out std_logic_vector(7 downto 0);
		io_dout_strobe	: in  std_logic;
		allow_sdhc		: in  std_logic;
		sd_cs				: in  std_logic;
		sd_sck			: in  std_logic;
		sd_sdi			: in  std_logic;
		sd_sdo			: out std_logic
	);
	end component sd_card;

	-- Resets
	signal pll_locked_s		: std_logic;
	signal por_s				: std_logic;
	signal reset_s				: std_logic;
	signal soft_por_s			: std_logic;
	signal soft_reset_k_s	: std_logic;
	signal soft_reset_s_s	: std_logic;
	signal soft_rst_cnt_s	: unsigned( 7 downto 0)	:= X"FF";

	-- Clocks
	signal clock_master_s	: std_logic;
	signal clock_sdram_s		: std_logic;
	signal clock_vdp_s		: std_logic;
	signal clock_cpu_s		: std_logic;
	signal clock_psg_en_s	: std_logic;
	signal clock_3m_s			: std_logic;
	signal turbo_on_s			: std_logic;

	-- RAM
	signal ram_addr_s			: std_logic_vector(22 downto 0);		-- 8MB
	signal ram_data_from_s	: std_logic_vector( 7 downto 0);
	signal ram_data_to_s		: std_logic_vector( 7 downto 0);
	signal ram_ce_s			: std_logic;
	signal ram_oe_s			: std_logic;
	signal ram_we_s			: std_logic;

	-- VRAM memory
	signal vram_addr_s		: std_logic_vector(13 downto 0);		-- 16K
	signal vram_data_from_s	: std_logic_vector( 7 downto 0);
	signal vram_data_to_s	: std_logic_vector( 7 downto 0);
--	signal vram_ce_s			: std_logic;
--	signal vram_oe_s			: std_logic;
	signal vram_we_s			: std_logic;

	-- Audio
	signal audio_scc_s		: signed(14 downto 0);
	signal audio_psg_s		: unsigned(7 downto 0);
	signal beep_s				: std_logic;
	signal k7_ai_s				: std_logic;

	-- Video
	signal rgb_r_s				: std_logic_vector( 3 downto 0);
	signal rgb_g_s				: std_logic_vector( 3 downto 0);
	signal rgb_b_s				: std_logic_vector( 3 downto 0);
	signal rgb_hsync_n_s		: std_logic;
	signal rgb_vsync_n_s		: std_logic;
--	signal ntsc_pal_s			: std_logic;
--	signal vga_en_s			: std_logic;
	signal pixel_clock_s		: std_logic;

	-- Keyboard
	signal rows_s				: std_logic_vector( 3 downto 0);
	signal cols_s				: std_logic_vector( 7 downto 0);
	signal caps_en_s			: std_logic;
	signal extra_keys_s		: std_logic_vector( 3 downto 0);
	signal keymap_addr_s		: std_logic_vector( 9 downto 0);
	signal keymap_data_s		: std_logic_vector( 7 downto 0);
	signal keymap_we_s		: std_logic;

	-- signals to connect sd card emulation with io controller
	signal sd_lba_s					: std_logic_vector(31 downto 0);
	signal sd_rd_s						: std_logic;
	signal sd_wr_s						: std_logic;
	signal sd_ack_s					: std_logic;
	signal sd_conf_s					: std_logic;
	signal sd_sdhc_s					: std_logic;
	signal sd_allow_sdhc_s			: std_logic;
	signal sd_allow_sdhcD_s			: std_logic;
	signal sd_allow_sdhcD2_s		: std_logic;
	signal sd_allow_sdhc_changed_s	: std_logic;
	-- data from io controller to sd card emulation
	signal sd_data_in_s				: std_logic_vector(7 downto 0);
	signal sd_data_in_strobe_s		: std_logic;
	signal sd_data_out_s				: std_logic_vector(7 downto 0);
	signal sd_data_out_strobe_s	: std_logic;
	-- sd card emulation
	signal sd_cs_s						: std_logic;
	signal sd_sck_s					: std_logic;
	signal sd_sdi_s					: std_logic;
	signal sd_sdo_s					: std_logic;

	-- PS/2
	signal ps2_clk_s			: std_logic;
	signal ps2counter_q		: unsigned(10 downto 0);
	signal ps2_keyboard_clk_in_s	: std_logic;
	signal ps2_keyboard_dat_in_s	: std_logic;

	-- Bus
	signal bus_addr_s			: std_logic_vector(15 downto 0);
	signal bus_data_from_s	: std_logic_vector( 7 downto 0)		:= (others => '1');
	signal bus_data_to_s		: std_logic_vector( 7 downto 0);
	signal bus_rd_n_s			: std_logic;
	signal bus_wr_n_s			: std_logic;
	signal bus_m1_n_s			: std_logic;
	signal bus_iorq_n_s		: std_logic;
	signal bus_mreq_n_s		: std_logic;
	signal bus_sltsl1_n_s	: std_logic;
	signal bus_sltsl2_n_s	: std_logic;

	-- JT51
	signal jt51_cs_n_s		: std_logic;
	signal jt51_left_s		: signed(15 downto 0)				:= (others => '0');
	signal jt51_right_s		: signed(15 downto 0)				:= (others => '0');

	-- Debug
	signal D_display_s		: std_logic_vector(15 downto 0);

begin

	-- PLL
	pll_1: entity work.pll1
	port map (
		inclk0	=> clk27_i(0),
		c0			=> clock_master_s,		-- 21.428571 MHz (6x NTSC)
		c1			=> clock_sdram_s,			-- 85.714286
		c2			=> sdram_clk_o,			-- 85.714286 -45°
		locked	=> pll_locked_s
	);

	-- Clocks
	clks: entity work.clocks
	port map (
		clock_i			=> clock_master_s,
		por_i				=> not pll_locked_s,
		turbo_on_i		=> turbo_on_s,
		clock_vdp_o		=> clock_vdp_s,
		clock_5m_en_o	=> open,
		clock_cpu_o		=> clock_cpu_s,
		clock_psg_en_o	=> clock_psg_en_s,
		clock_3m_o		=> clock_3m_s
	);

	-- The MSX1
	the_msx: entity work.msx
	generic map (
		hw_id_g			=> 8,
		hw_txt_g			=> "MiST Board",
		hw_version_g	=> X"12",
		video_opt_g		=> 1,						-- 1 = dblscan configurable
		ramsize_g		=> 8192
	)
	port map (
		-- Clocks
		clock_i			=> clock_master_s,
		clock_vdp_i		=> clock_vdp_s,
		clock_cpu_i		=> clock_cpu_s,
		clock_psg_en_i	=> clock_psg_en_s,
		-- Turbo
		turbo_on_k_i	=> extra_keys_s(3),	-- F11
		turbo_on_o		=> turbo_on_s,
		-- Resets
		reset_i			=> reset_s,
		por_i				=> por_s,
		softreset_o		=> soft_reset_s_s,
		-- Options
		opt_nextor_i	=> '1',
		opt_mr_type_i	=> "00",
		opt_vga_on_i	=> '0',
		-- RAM
		ram_addr_o		=> ram_addr_s,
		ram_data_i		=> ram_data_from_s,
		ram_data_o		=> ram_data_to_s,
		ram_ce_o			=> ram_ce_s,
		ram_we_o			=> ram_we_s,
		ram_oe_o			=> ram_oe_s,
		-- ROM
		rom_addr_o		=> open,
		rom_data_i		=> ram_data_from_s,
		rom_ce_o			=> open,
		rom_oe_o			=> open,
		-- External bus
		bus_addr_o		=> bus_addr_s,
		bus_data_i		=> bus_data_from_s,
		bus_data_o		=> bus_data_to_s,
		bus_rd_n_o		=> bus_rd_n_s,
		bus_wr_n_o		=> bus_wr_n_s,
		bus_m1_n_o		=> bus_m1_n_s,
		bus_iorq_n_o	=> bus_iorq_n_s,
		bus_mreq_n_o	=> bus_mreq_n_s,
		bus_sltsl1_n_o	=> bus_sltsl1_n_s,
		bus_sltsl2_n_o	=> bus_sltsl2_n_s,
		bus_wait_n_i	=> '1',
		bus_nmi_n_i		=> '1',
		bus_int_n_i		=> '1',
		-- VDP RAM
		vram_addr_o		=> vram_addr_s,
		vram_data_i		=> vram_data_from_s,
		vram_data_o		=> vram_data_to_s,
		vram_ce_o		=> open,--vram_ce_s,
		vram_oe_o		=> open,--vram_oe_s,
		vram_we_o		=> vram_we_s,
		-- Keyboard
		rows_o			=> rows_s,
		cols_i			=> cols_s,
		caps_en_o		=> caps_en_s,
		keymap_addr_o	=> keymap_addr_s,
		keymap_data_o	=> keymap_data_s,
		keymap_we_o		=> keymap_we_s,
		-- Audio
		audio_scc_o		=> audio_scc_s,
		audio_psg_o		=> audio_psg_s,
		beep_o			=> beep_s,
		-- K7
		k7_motor_o		=> open,
		k7_audio_o		=> open,
		k7_audio_i		=> k7_ai_s,
		-- Joystick
		joy1_up_i		=> '0',
		joy1_down_i		=> '0',
		joy1_left_i		=> '0',
		joy1_right_i	=> '0',
		joy1_btn1_i		=> '0',
		joy1_btn1_o		=> open,
		joy1_btn2_i		=> '0',
		joy1_btn2_o		=> open,
		joy1_out_o		=> open,
		joy2_up_i		=> '0',
		joy2_down_i		=> '0',
		joy2_left_i		=> '0',
		joy2_right_i	=> '0',
		joy2_btn1_i		=> '0',
		joy2_btn1_o		=> open,
		joy2_btn2_i		=> '0',
		joy2_btn2_o		=> open,
		joy2_out_o		=> open,
		-- Video
		pixel_clock_o	=> pixel_clock_s,
		rgb_r_o			=> rgb_r_s,
		rgb_g_o			=> rgb_g_s,
		rgb_b_o			=> rgb_b_s,
		hsync_n_o		=> rgb_hsync_n_s,
		vsync_n_o		=> rgb_vsync_n_s,
		ntsc_pal_o		=> open,--ntsc_pal_s,
		vga_on_k_i		=> extra_keys_s(2),			-- Print Screen
		scanline_on_k_i=> '0',--extra_keys_s(1),		-- Scroll Lock
		vga_en_o			=> open,--vga_en_s,
		-- SPI/SD
		flspi_cs_n_o	=> open,
		spi_cs_n_o		=> sd_cs_s,
		spi_sclk_o		=> sd_sck_s,
		spi_mosi_o		=> sd_sdo_s,
		spi_miso_i		=> sd_sdi_s,
		sd_pres_n_i		=> '0',
		sd_wp_i			=> '0',
		-- DEBUG
		D_wait_o			=> open,
		D_slots_o		=> open,
		D_ipl_en_o		=> open
	 );

	-- Keyboard PS/2
	keyb: entity work.keyboard
	port map (
		clock_i			=> clock_3m_s,
		reset_i			=> reset_s,
		-- MSX
		rows_coded_i	=> rows_s,
		cols_o			=> cols_s,
		keymap_addr_i	=> keymap_addr_s,
		keymap_data_i	=> keymap_data_s,
		keymap_we_i		=> keymap_we_s,
		-- LEDs
		led_caps_i		=> caps_en_s,
		-- PS/2 interface
		ps2_clk_i		=> ps2_keyboard_clk_in_s,
		ps2_clk_o		=> open,
		ps2_data_i		=> ps2_keyboard_dat_in_s,
		ps2_data_o		=> open,
		--
		reset_o			=> soft_reset_k_s,
		por_o				=> soft_por_s,
		reload_core_o	=> open,
		extra_keys_o	=> extra_keys_s
	);

	-- Audio
	audio: entity work.Audio_DACs
	port map (
		clock_i			=> clock_master_s,
		reset_i			=> reset_s,
		audio_scc_i		=> audio_scc_s,
		audio_psg_i		=> audio_psg_s,
		jt51_left_i		=> jt51_left_s,
		jt51_right_i	=> jt51_right_s,
		beep_i			=> beep_s,
		audio_mix_l_o	=> open,
		audio_mix_r_o	=> open,
		dacout_l_o		=> audio_l_o,
		dacout_r_o		=> audio_r_o
	);

	-- VRAM
	vram: entity work.spram
	generic map (
		addr_width_g => 14,
		data_width_g => 8
	)
	port map (
		clk_i		=> clock_master_s,
		we_i		=> vram_we_s,
		addr_i	=> vram_addr_s,
		data_i	=> vram_data_to_s,
		data_o	=> vram_data_from_s
	);

	-- RAM
	ram: entity work.ssdram
	generic map (
		freq_g		=> 86
	)
	port map (
		clock_i		=> clock_sdram_s,
		reset_i		=> reset_s,
		refresh_i	=> '1',
		-- Static RAM bus
		addr_i		=> ram_addr_s,
		data_i		=> ram_data_to_s,
		data_o		=> ram_data_from_s,
		cs_i			=> ram_ce_s,
		oe_i			=> ram_oe_s,
		we_i			=> ram_we_s,
		-- SD-RAM ports
		mem_cke_o	=> sdram_cke_o,
		mem_cs_n_o	=> sdram_cs_n_o,
		mem_ras_n_o	=> sdram_ras_n_o,
		mem_cas_n_o	=> sdram_cas_n_o,
		mem_we_n_o	=> sdram_we_n_o,
		mem_udq_o	=> sdram_udqm_o,
		mem_ldq_o	=> sdram_ldqm_o,
		mem_ba_o		=> sdram_ba_o,
		mem_addr_o	=> sdram_addr_o(11 downto 0),
		mem_data_io	=> sdram_data_io
	);

	osd_inst : osd
	port map (
		pclk			=> pixel_clock_s,
		sdi			=> spi_di_i,
		sck			=> spi_sck_i,
		ss				=> spi_ss3_i,
		red_in		=> rgb_r_s & "00",
		green_in		=> rgb_g_s & "00",
		blue_in		=> rgb_b_s & "00",
		hs_in			=> rgb_hsync_n_s,
		vs_in			=> rgb_vsync_n_s,
		red_out		=> vga_r_o,
		green_out	=> vga_g_o,
		blue_out		=> vga_b_o,
		osd_enable	=> open
	);

	-- VGA Output
	vga_hsync_n_o	<= rgb_hsync_n_s;
	vga_vsync_n_o	<= rgb_vsync_n_s;

	userio_inst : user_io
	generic map (
		STRLEN => CONF_STR'length
	)
	port map (
		conf_str					=> to_slv(CONF_STR),
		SPI_SCK					=> spi_sck_i,
		CONF_DATA0				=> conf_data0_i,
		SPI_DI					=> spi_di_i,
		SPI_DO	 				=> spi_do_io,
		joystick_0				=> open,
		joystick_1				=> open,
		joystick_analog_0		=> open,
		joystick_analog_1		=> open,
		buttons					=> open,
		switches					=> open,
		scandoubler_disable	=> open,
		status					=> open,
		-- SD Card Emulation
		sd_lba					=> sd_lba_s,
		sd_rd						=> sd_rd_s,
		sd_wr						=> sd_wr_s,
		sd_ack					=> sd_ack_s,
		sd_sdhc					=> sd_sdhc_s,
		sd_conf					=> sd_conf_s,
 		sd_dout					=> sd_data_in_s,
 		sd_dout_strobe			=> sd_data_in_strobe_s,
		sd_din					=> sd_data_out_s,
		sd_din_strobe			=> sd_data_out_strobe_s,
		sd_mounted				=> open,
		-- ps2 keyboard emulation
		ps2_clk					=> ps2_clk_s,
		ps2_kbd_clk				=> ps2_keyboard_clk_in_s,
		ps2_kbd_data			=> ps2_keyboard_dat_in_s,
		ps2_mouse_clk			=> open,
		ps2_mouse_data			=> open,
		-- serial com port 
		serial_data				=> (others => '0'),
		serial_strobe			=> '0'
	);

	sd_card_d: component sd_card
	port map (
		-- connection to io controller
		io_lba			=> sd_lba_s,
		io_rd				=> sd_rd_s,
		io_wr				=> sd_wr_s,
		io_ack			=> sd_ack_s,
		io_conf			=> sd_conf_s,
		io_sdhc			=>	sd_sdhc_s,
		io_din			=> sd_data_in_s,
		io_din_strobe	=> sd_data_in_strobe_s,
		io_dout			=> sd_data_out_s,
		io_dout_strobe	=> sd_data_out_strobe_s,
		allow_sdhc		=> '1',
		-- connection to host
		sd_cs				=> sd_cs_s,
		sd_sck			=> sd_sck_s,
		sd_sdi			=> sd_sdo_s,
		sd_sdo			=> sd_sdi_s		
	);

	-- Resets
	por_s			<= '1'	when pll_locked_s = '0' or soft_por_s = '1'	else '0';
	reset_s		<= '1'	when soft_rst_cnt_s = X"00" or por_s = '1'	else '0';

	process(clock_master_s)
	begin
		if rising_edge(clock_master_s) then
			if reset_s = '1' or por_s = '1' then
				soft_rst_cnt_s	<= X"FF";
			elsif (soft_reset_k_s = '1' or soft_reset_s_s = '1') and soft_rst_cnt_s /= X"00" then
				soft_rst_cnt_s <= soft_rst_cnt_s - 1;
			end if;
		end if;
	end process;

	-- PS/2 clock
	process(clock_master_s)
	begin
		if rising_edge(clock_master_s) then
			ps2counter_q <= ps2counter_q + 1;
			if ps2counter_q = 1200 then
				ps2_clk_s		<= not ps2_clk_s;
				ps2counter_q	<= (others => '0');
			end if;
		end if;
	end process;

	ptjt: if per_jt51_g generate
		-- JT51 tests
		jt51_cs_n_s <= '0' when bus_addr_s(7 downto 1) = "0010000" and bus_iorq_n_s = '0' and bus_m1_n_s = '1'	else '1';	-- 0x20 - 0x21

		jt51: entity work.jt51_wrapper
		port map (
			clock_i			=> clock_3m_s,
			reset_i			=> reset_s,
			addr_i			=> bus_addr_s(0),
			cs_n_i			=> jt51_cs_n_s,
			wr_n_i			=> bus_wr_n_s,
			rd_n_i			=> bus_rd_n_s,
			data_i			=> bus_data_to_s,
			data_o			=> bus_data_from_s,
			ct1_o				=> open,
			ct2_o				=> open,
			irq_n_o			=> open,
			p1_o				=> open,
			-- Low resolution output (same as real chip)
			sample_o			=> open,
			left_o			=> open,
			right_o			=> open,
			-- Full resolution output
			xleft_o			=> jt51_left_s,
			xright_o			=> jt51_right_s,
			-- unsigned outputs for sigma delta converters, full resolution		
			dacleft_o		=> open,
			dacright_o		=> open
		);
	end generate;

	-- Debug
	led_n_o	<= sd_cs_s;
	
end architecture;