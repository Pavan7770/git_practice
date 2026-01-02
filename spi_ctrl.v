//this file is edited by pavan

module spi_ctrl(
//apb
pclk_i,prst_i,pwrite_i,paddr_i,pwdata_i,prdata_o,penable_i,pready_o,perror_o,
//spi
sclk_i,sclk_o,miso,mosi,ss);
parameter ADDR_WIDTH=8;
parameter DATA_WIDTH=8;
parameter NUM_REGS=8;
parameter S_IDLE				 =5'b00001;
parameter S_ADDR_PHASE			 =5'b00010;
parameter S_IDLE_BW_ADDR_DATA	 =5'b00100;
parameter S_DATA_PHASE			 =5'b01000;
parameter S_IDLE_WITH_TXS_PENDING=5'b10000;
input pclk_i,prst_i;
input sclk_i;
input pwrite_i;
input [ADDR_WIDTH-1:0]paddr_i;
input [DATA_WIDTH-1:0]pwdata_i;
output reg [DATA_WIDTH-1:0]prdata_o;
input penable_i;
output reg pready_o,perror_o;
output reg sclk_o;
input miso;
output reg mosi;
output reg ss;
//register ,nets
reg[ADDR_WIDTH-1:0]addr_regA[NUM_REGS-1:0];
reg[DATA_WIDTH-1:0]data_regA[NUM_REGS-1:0];
reg[DATA_WIDTH-1:0]ctrl_reg;
integer i;
reg[4:0]state,n_state;
reg[7:0]rx_data;//data driven by spi slave during the read txs

reg [2:0] next_txt_index;
reg [ADDR_WIDTH-1:0]addr_to_drive;
reg [DATA_WIDTH-1:0]data_to_drive;
reg [3:0] num_txs;
integer count;

//implement logic to write and read these registers
always@(posedge pclk_i)begin
	if(prst_i==1)begin
	//make all reg variables to rest value 0
		pready_o=0;
		perror_o=0;
		prdata_o=0;
		state=S_IDLE;
		n_state=S_IDLE;

		for(i=0;i<NUM_REGS;i=i+1) begin
			addr_regA[i]=0;
			data_regA[i]=0;
		end
		ctrl_reg=0;
		mosi=1;
		sclk_o=1;
		ss=0;
	end
	else begin
		if(penable_i==1)begin
			pready_o=1;
			if(pwrite_i==1)begin
				if(paddr_i>=8'h0&&paddr_i<=8'h7)begin
					addr_regA[paddr_i]=pwdata_i;
				end
				else if(paddr_i>=8'h10&&paddr_i<=8'h17)begin
					data_regA[paddr_i-8'h10]=pwdata_i;
				end
				else if(paddr_i==8'h20)begin
					ctrl_reg=pwdata_i;
				end
				else begin
					$display("Decode error write targeting non existant register");

				end
			end
			else begin
				if(paddr_i>=8'h0&&paddr_i<=8'h7)begin
					prdata_o=addr_regA[paddr_i];
				end
				else if(paddr_i>=8'h10&&paddr_i<=8'h17)begin
					prdata_o=data_regA[paddr_i-8'h10];
				end
				else if(paddr_i==8'h20)begin
					prdata_o=ctrl_reg;
				end

			end
		end	
		else begin
			pready_o=0;
		end
	end
end
always@(posedge sclk_i)begin
if(prst_i==0)begin//if reset is not applied
	case(state)
		S_IDLE:begin
			if(ctrl_reg[0]==1)begin
				n_state=S_ADDR_PHASE;
				count=0;
				num_txs=ctrl_reg[3:1]+1;
				next_txt_index=ctrl_reg[6:4];
				addr_to_drive=addr_regA[next_txt_index];//important
				data_to_drive=data_regA[next_txt_index];//only used in case of write tx
			end
		end
		S_ADDR_PHASE:begin
			mosi=addr_to_drive[count];
			count=count+1;
			if(count==8)begin
				n_state=S_IDLE_BW_ADDR_DATA;
				count=0;
			end
		end
		S_IDLE_BW_ADDR_DATA:begin
			count=count+1;
			if(count==4)begin
			n_state=S_DATA_PHASE;
			count=0;
			end
		end
		S_DATA_PHASE:begin
			if(addr_to_drive[7]==1)begin//write
				mosi=data_to_drive[count];
			end
			else begin
				rx_data[count]=miso;
			end
			count=count+1;
			if(count==8)begin
				num_txs=num_txs-1;
				ctrl_reg[6:4]=ctrl_reg[6:4]+1;//incrementing next_tx_index
				if(num_txs==0)n_state=S_IDLE;
				else n_state=S_IDLE_WITH_TXS_PENDING;
				count=0;
			end
		end
		S_IDLE_WITH_TXS_PENDING:begin
			count=count+1;
			if(count==6)begin
				next_txt_index=ctrl_reg[6:4];
				addr_to_drive=addr_regA[next_txt_index];//important
				data_to_drive=data_regA[next_txt_index];//only used in case of write tx
				n_state=S_ADDR_PHASE;
				count=0;

			end
		end
	endcase
end
end
always@(n_state) state=n_state;

endmodule


