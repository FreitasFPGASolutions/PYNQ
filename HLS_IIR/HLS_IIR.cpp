#include "ap_fixed.h"
#include "ap_axi_sdata.h"
#include "hls_stream.h"

void HLS_IIR(stream<ap_axis<16,0,0,0>> &x,
		     ap_fixed<18, 2, AP_TRN, AP_SAT> alpha,
			 stream<ap_axis<16,0,0,0>> &y)
{
#pragma HLS PIPELINE II=1
#pragma HLS INTERFACE axis port=x
#pragma HLS INTERFACE s_axilite port=alpha
#pragma HLS INTERFACE axis port=y
#pragma HLS INTERFACE ap_ctrl_none port=return

ap_axis<16,0,0,0> x_in;
ap_fixed<16, 16, AP_TRN, AP_SAT> x_in_fixed;
ap_fixed<16, 16, AP_TRN, AP_SAT> y_out_fixed = 0;
ap_fixed<18,  2, AP_TRN, AP_SAT> ONE = 1;

while(1)
{
	x.read(x_in);

	x_in_fixed.range() = x_in.data.range();
	y_out_fixed = (ONE - alpha) * x_in_fixed + alpha * y_out_fixed;

	x_in.data.range() = y_out_fixed.range();
	y.write(x_in);
	if(x_in.last)
	{
		y_out_fixed = 0;
		break;
	}
}
}
