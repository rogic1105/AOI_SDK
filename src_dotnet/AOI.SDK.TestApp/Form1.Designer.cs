// AOI_SDK\src_dotnet\AOI.SDK.TestApp\Form1.Designer.cs

namespace AOI.SDK.TestApp
{
    partial class Form1
    {
        /// <summary>
        /// 設計工具所需的變數。
        /// </summary>
        private System.ComponentModel.IContainer components = null;

        /// <summary>
        /// 清除任何使用中的資源。
        /// </summary>
        /// <param name="disposing">如果應該處置受控資源則為 true，否則為 false。</param>
        protected override void Dispose(bool disposing)
        {
            if (disposing && (components != null))
            {
                components.Dispose();
            }
            base.Dispose(disposing);
        }

        #region Windows Form 設計工具產生的程式碼

        /// <summary>
        /// 此為設計工具支援所需的方法 - 請勿使用程式碼編輯器修改
        /// 這個方法的內容。
        /// </summary>
        private void InitializeComponent()
        {
            this.tabControl1 = new System.Windows.Forms.TabControl();
            this.tabPage1 = new System.Windows.Forms.TabPage();
            this.splitContainer1 = new System.Windows.Forms.SplitContainer();
            this.btnSave = new System.Windows.Forms.Button();
            this.groupBox2 = new System.Windows.Forms.GroupBox();
            this.numBrightVal = new System.Windows.Forms.NumericUpDown();
            this.btnConvolution = new System.Windows.Forms.Button();
            this.label2 = new System.Windows.Forms.Label();
            this.numThreshold = new System.Windows.Forms.NumericUpDown();
            this.btnBrighten = new System.Windows.Forms.Button();
            this.btnInvert = new System.Windows.Forms.Button();
            this.label1 = new System.Windows.Forms.Label();
            this.btnBinary = new System.Windows.Forms.Button();
            this.btnReset = new System.Windows.Forms.Button();
            this.btnLoad = new System.Windows.Forms.Button();
            this.canvasMain = new AOI.SDK.UI.SmartCanvas();
            this.statusStrip1 = new System.Windows.Forms.StatusStrip();
            this.lblPixelInfo = new System.Windows.Forms.ToolStripStatusLabel();
            this.tabPage2 = new System.Windows.Forms.TabPage();
            this.txtLoadPath = new System.Windows.Forms.TextBox();
            this.txtSavePath = new System.Windows.Forms.TextBox();
            this.btnOpenSaveDir = new System.Windows.Forms.Button();
            this.btnOpenLoadDir = new System.Windows.Forms.Button();
            this.tabControl1.SuspendLayout();
            this.tabPage1.SuspendLayout();
            ((System.ComponentModel.ISupportInitialize)(this.splitContainer1)).BeginInit();
            this.splitContainer1.Panel1.SuspendLayout();
            this.splitContainer1.Panel2.SuspendLayout();
            this.splitContainer1.SuspendLayout();
            this.groupBox2.SuspendLayout();
            ((System.ComponentModel.ISupportInitialize)(this.numBrightVal)).BeginInit();
            ((System.ComponentModel.ISupportInitialize)(this.numThreshold)).BeginInit();
            ((System.ComponentModel.ISupportInitialize)(this.canvasMain)).BeginInit();
            this.statusStrip1.SuspendLayout();
            this.SuspendLayout();
            // 
            // tabControl1
            // 
            this.tabControl1.Controls.Add(this.tabPage1);
            this.tabControl1.Controls.Add(this.tabPage2);
            this.tabControl1.Dock = System.Windows.Forms.DockStyle.Fill;
            this.tabControl1.Font = new System.Drawing.Font("Arial Black", 9F, System.Drawing.FontStyle.Regular, System.Drawing.GraphicsUnit.Point, ((byte)(136)));
            this.tabControl1.Location = new System.Drawing.Point(0, 0);
            this.tabControl1.Margin = new System.Windows.Forms.Padding(4);
            this.tabControl1.Name = "tabControl1";
            this.tabControl1.SelectedIndex = 0;
            this.tabControl1.Size = new System.Drawing.Size(1138, 543);
            this.tabControl1.TabIndex = 0;
            // 
            // tabPage1
            // 
            this.tabPage1.Controls.Add(this.splitContainer1);
            this.tabPage1.Location = new System.Drawing.Point(4, 25);
            this.tabPage1.Margin = new System.Windows.Forms.Padding(4);
            this.tabPage1.Name = "tabPage1";
            this.tabPage1.Padding = new System.Windows.Forms.Padding(4);
            this.tabPage1.Size = new System.Drawing.Size(1130, 514);
            this.tabPage1.TabIndex = 0;
            this.tabPage1.Text = "Unit Test";
            this.tabPage1.UseVisualStyleBackColor = true;
            // 
            // splitContainer1
            // 
            this.splitContainer1.Dock = System.Windows.Forms.DockStyle.Fill;
            this.splitContainer1.Location = new System.Drawing.Point(4, 4);
            this.splitContainer1.Margin = new System.Windows.Forms.Padding(4);
            this.splitContainer1.Name = "splitContainer1";
            // 
            // splitContainer1.Panel1
            // 
            this.splitContainer1.Panel1.Controls.Add(this.btnOpenLoadDir);
            this.splitContainer1.Panel1.Controls.Add(this.btnOpenSaveDir);
            this.splitContainer1.Panel1.Controls.Add(this.txtSavePath);
            this.splitContainer1.Panel1.Controls.Add(this.txtLoadPath);
            this.splitContainer1.Panel1.Controls.Add(this.btnSave);
            this.splitContainer1.Panel1.Controls.Add(this.groupBox2);
            this.splitContainer1.Panel1.Controls.Add(this.btnReset);
            this.splitContainer1.Panel1.Controls.Add(this.btnLoad);
            // 
            // splitContainer1.Panel2
            // 
            this.splitContainer1.Panel2.Controls.Add(this.canvasMain);
            this.splitContainer1.Panel2.Controls.Add(this.statusStrip1);
            this.splitContainer1.Size = new System.Drawing.Size(1122, 506);
            this.splitContainer1.SplitterDistance = 372;
            this.splitContainer1.SplitterWidth = 5;
            this.splitContainer1.TabIndex = 0;
            // 
            // btnSave
            // 
            this.btnSave.Location = new System.Drawing.Point(16, 91);
            this.btnSave.Margin = new System.Windows.Forms.Padding(4);
            this.btnSave.Name = "btnSave";
            this.btnSave.Size = new System.Drawing.Size(100, 29);
            this.btnSave.TabIndex = 7;
            this.btnSave.Text = "Save Image";
            this.btnSave.UseVisualStyleBackColor = true;
            this.btnSave.Click += new System.EventHandler(this.btnSave_Click);
            // 
            // groupBox2
            // 
            this.groupBox2.Controls.Add(this.numBrightVal);
            this.groupBox2.Controls.Add(this.btnConvolution);
            this.groupBox2.Controls.Add(this.label2);
            this.groupBox2.Controls.Add(this.numThreshold);
            this.groupBox2.Controls.Add(this.btnBrighten);
            this.groupBox2.Controls.Add(this.btnInvert);
            this.groupBox2.Controls.Add(this.label1);
            this.groupBox2.Controls.Add(this.btnBinary);
            this.groupBox2.Location = new System.Drawing.Point(16, 279);
            this.groupBox2.Name = "groupBox2";
            this.groupBox2.Size = new System.Drawing.Size(333, 202);
            this.groupBox2.TabIndex = 7;
            this.groupBox2.TabStop = false;
            this.groupBox2.Text = "IMP";
            // 
            // numBrightVal
            // 
            this.numBrightVal.Location = new System.Drawing.Point(221, 96);
            this.numBrightVal.Margin = new System.Windows.Forms.Padding(4);
            this.numBrightVal.Maximum = new decimal(new int[] {
            255,
            0,
            0,
            0});
            this.numBrightVal.Minimum = new decimal(new int[] {
            255,
            0,
            0,
            -2147483648});
            this.numBrightVal.Name = "numBrightVal";
            this.numBrightVal.Size = new System.Drawing.Size(76, 29);
            this.numBrightVal.TabIndex = 3;
            this.numBrightVal.Value = new decimal(new int[] {
            50,
            0,
            0,
            0});
            // 
            // btnConvolution
            // 
            this.btnConvolution.Location = new System.Drawing.Point(14, 134);
            this.btnConvolution.Margin = new System.Windows.Forms.Padding(4);
            this.btnConvolution.Name = "btnConvolution";
            this.btnConvolution.Size = new System.Drawing.Size(100, 29);
            this.btnConvolution.TabIndex = 6;
            this.btnConvolution.Text = "Convolution";
            this.btnConvolution.UseVisualStyleBackColor = true;
            this.btnConvolution.Click += new System.EventHandler(this.btnConvolution_Click);
            // 
            // label2
            // 
            this.label2.AutoSize = true;
            this.label2.Location = new System.Drawing.Point(132, 103);
            this.label2.Margin = new System.Windows.Forms.Padding(4, 0, 4, 0);
            this.label2.Name = "label2";
            this.label2.Size = new System.Drawing.Size(67, 15);
            this.label2.TabIndex = 1;
            this.label2.Text = "亮度增量";
            // 
            // numThreshold
            // 
            this.numThreshold.Location = new System.Drawing.Point(221, 27);
            this.numThreshold.Margin = new System.Windows.Forms.Padding(4);
            this.numThreshold.Maximum = new decimal(new int[] {
            255,
            0,
            0,
            0});
            this.numThreshold.Name = "numThreshold";
            this.numThreshold.Size = new System.Drawing.Size(76, 29);
            this.numThreshold.TabIndex = 2;
            this.numThreshold.Value = new decimal(new int[] {
            128,
            0,
            0,
            0});
            // 
            // btnBrighten
            // 
            this.btnBrighten.Location = new System.Drawing.Point(11, 96);
            this.btnBrighten.Margin = new System.Windows.Forms.Padding(4);
            this.btnBrighten.Name = "btnBrighten";
            this.btnBrighten.Size = new System.Drawing.Size(100, 29);
            this.btnBrighten.TabIndex = 4;
            this.btnBrighten.Text = "Brighten";
            this.btnBrighten.UseVisualStyleBackColor = true;
            this.btnBrighten.Click += new System.EventHandler(this.btnBrighten_Click);
            // 
            // btnInvert
            // 
            this.btnInvert.Location = new System.Drawing.Point(11, 59);
            this.btnInvert.Margin = new System.Windows.Forms.Padding(4);
            this.btnInvert.Name = "btnInvert";
            this.btnInvert.Size = new System.Drawing.Size(100, 29);
            this.btnInvert.TabIndex = 3;
            this.btnInvert.Text = "Invert";
            this.btnInvert.UseVisualStyleBackColor = true;
            this.btnInvert.Click += new System.EventHandler(this.btnInvert_Click);
            // 
            // label1
            // 
            this.label1.AutoSize = true;
            this.label1.Location = new System.Drawing.Point(132, 29);
            this.label1.Margin = new System.Windows.Forms.Padding(4, 0, 4, 0);
            this.label1.Name = "label1";
            this.label1.Size = new System.Drawing.Size(52, 15);
            this.label1.TabIndex = 0;
            this.label1.Text = "門檻值";
            // 
            // btnBinary
            // 
            this.btnBinary.Location = new System.Drawing.Point(14, 22);
            this.btnBinary.Margin = new System.Windows.Forms.Padding(4);
            this.btnBinary.Name = "btnBinary";
            this.btnBinary.Size = new System.Drawing.Size(100, 29);
            this.btnBinary.TabIndex = 2;
            this.btnBinary.Text = "Binary";
            this.btnBinary.UseVisualStyleBackColor = true;
            this.btnBinary.Click += new System.EventHandler(this.btnBinary_Click);
            // 
            // btnReset
            // 
            this.btnReset.Location = new System.Drawing.Point(16, 177);
            this.btnReset.Margin = new System.Windows.Forms.Padding(4);
            this.btnReset.Name = "btnReset";
            this.btnReset.Size = new System.Drawing.Size(100, 29);
            this.btnReset.TabIndex = 5;
            this.btnReset.Text = "Reset";
            this.btnReset.UseVisualStyleBackColor = true;
            this.btnReset.Click += new System.EventHandler(this.btnReset_Click);
            // 
            // btnLoad
            // 
            this.btnLoad.Location = new System.Drawing.Point(16, 19);
            this.btnLoad.Margin = new System.Windows.Forms.Padding(4);
            this.btnLoad.Name = "btnLoad";
            this.btnLoad.Size = new System.Drawing.Size(100, 29);
            this.btnLoad.TabIndex = 0;
            this.btnLoad.Text = "Load Image";
            this.btnLoad.UseVisualStyleBackColor = true;
            this.btnLoad.Click += new System.EventHandler(this.btnLoad_Click);
            // 
            // canvasMain
            // 
            this.canvasMain.BackColor = System.Drawing.Color.Black;
            this.canvasMain.Cursor = System.Windows.Forms.Cursors.Cross;
            this.canvasMain.Dock = System.Windows.Forms.DockStyle.Fill;
            this.canvasMain.Location = new System.Drawing.Point(0, 0);
            this.canvasMain.Name = "canvasMain";
            this.canvasMain.Size = new System.Drawing.Size(745, 481);
            this.canvasMain.TabIndex = 2;
            this.canvasMain.TabStop = false;
            // 
            // statusStrip1
            // 
            this.statusStrip1.ImageScalingSize = new System.Drawing.Size(20, 20);
            this.statusStrip1.Items.AddRange(new System.Windows.Forms.ToolStripItem[] {
            this.lblPixelInfo});
            this.statusStrip1.Location = new System.Drawing.Point(0, 481);
            this.statusStrip1.Name = "statusStrip1";
            this.statusStrip1.Padding = new System.Windows.Forms.Padding(1, 0, 19, 0);
            this.statusStrip1.Size = new System.Drawing.Size(745, 25);
            this.statusStrip1.TabIndex = 1;
            this.statusStrip1.Text = "statusStrip1";
            // 
            // lblPixelInfo
            // 
            this.lblPixelInfo.Name = "lblPixelInfo";
            this.lblPixelInfo.Size = new System.Drawing.Size(53, 19);
            this.lblPixelInfo.Text = "Ready";
            // 
            // tabPage2
            // 
            this.tabPage2.Location = new System.Drawing.Point(4, 25);
            this.tabPage2.Margin = new System.Windows.Forms.Padding(4);
            this.tabPage2.Name = "tabPage2";
            this.tabPage2.Padding = new System.Windows.Forms.Padding(4);
            this.tabPage2.Size = new System.Drawing.Size(1130, 514);
            this.tabPage2.TabIndex = 1;
            this.tabPage2.Text = "Advanced";
            this.tabPage2.UseVisualStyleBackColor = true;
            // 
            // txtLoadPath
            // 
            this.txtLoadPath.Location = new System.Drawing.Point(16, 55);
            this.txtLoadPath.Name = "txtLoadPath";
            this.txtLoadPath.Size = new System.Drawing.Size(313, 29);
            this.txtLoadPath.TabIndex = 8;
            this.txtLoadPath.ReadOnly = true;
            this.txtLoadPath.BackColor = System.Drawing.SystemColors.ControlLightLight;
            // 
            // txtSavePath
            // 
            this.txtSavePath.Location = new System.Drawing.Point(16, 127);
            this.txtSavePath.Name = "txtSavePath";
            this.txtSavePath.Size = new System.Drawing.Size(313, 29);
            this.txtSavePath.TabIndex = 9;
            this.txtSavePath.ReadOnly = true;
            this.txtSavePath.BackColor = System.Drawing.SystemColors.ControlLightLight;
            // 
            // btnOpenSaveDir
            // 
            this.btnOpenSaveDir.Location = new System.Drawing.Point(133, 91);
            this.btnOpenSaveDir.Margin = new System.Windows.Forms.Padding(4);
            this.btnOpenSaveDir.Name = "btnOpenSaveDir";
            this.btnOpenSaveDir.Size = new System.Drawing.Size(67, 29);
            this.btnOpenSaveDir.TabIndex = 10;
            this.btnOpenSaveDir.Text = "📂";
            this.btnOpenSaveDir.UseVisualStyleBackColor = true;
            this.btnOpenSaveDir.Click += new System.EventHandler(this.btnOpenSaveDir_Click);
            // 
            // btnOpenLoadDir
            // 
            this.btnOpenLoadDir.Location = new System.Drawing.Point(133, 19);
            this.btnOpenLoadDir.Margin = new System.Windows.Forms.Padding(4);
            this.btnOpenLoadDir.Name = "btnOpenLoadDir";
            this.btnOpenLoadDir.Size = new System.Drawing.Size(67, 29);
            this.btnOpenLoadDir.TabIndex = 11;
            this.btnOpenLoadDir.Text = "📂";
            this.btnOpenLoadDir.UseVisualStyleBackColor = true;
            this.btnOpenLoadDir.Click += new System.EventHandler(this.btnOpenLoadDir_Click);
            // 
            // Form1
            // 
            this.AutoScaleDimensions = new System.Drawing.SizeF(8F, 15F);
            this.AutoScaleMode = System.Windows.Forms.AutoScaleMode.Font;
            this.ClientSize = new System.Drawing.Size(1138, 543);
            this.Controls.Add(this.tabControl1);
            this.Margin = new System.Windows.Forms.Padding(4);
            this.Name = "Form1";
            this.Text = "AOI SDK Test";
            this.tabControl1.ResumeLayout(false);
            this.tabPage1.ResumeLayout(false);
            this.splitContainer1.Panel1.ResumeLayout(false);
            this.splitContainer1.Panel1.PerformLayout();
            this.splitContainer1.Panel2.ResumeLayout(false);
            this.splitContainer1.Panel2.PerformLayout();
            ((System.ComponentModel.ISupportInitialize)(this.splitContainer1)).EndInit();
            this.splitContainer1.ResumeLayout(false);
            this.groupBox2.ResumeLayout(false);
            this.groupBox2.PerformLayout();
            ((System.ComponentModel.ISupportInitialize)(this.numBrightVal)).EndInit();
            ((System.ComponentModel.ISupportInitialize)(this.numThreshold)).EndInit();
            ((System.ComponentModel.ISupportInitialize)(this.canvasMain)).EndInit();
            this.statusStrip1.ResumeLayout(false);
            this.statusStrip1.PerformLayout();
            this.ResumeLayout(false);

        }

        #endregion

        private AOI.SDK.UI.SmartCanvas canvasMain;
        private System.Windows.Forms.TabControl tabControl1;
        private System.Windows.Forms.TabPage tabPage1;
        private System.Windows.Forms.TabPage tabPage2;
        private System.Windows.Forms.SplitContainer splitContainer1;
        private System.Windows.Forms.Label label1;
        private System.Windows.Forms.Button btnLoad;
        private System.Windows.Forms.StatusStrip statusStrip1;
        private System.Windows.Forms.ToolStripStatusLabel lblPixelInfo;
        private System.Windows.Forms.Label label2;
        private System.Windows.Forms.Button btnReset;
        private System.Windows.Forms.GroupBox groupBox2;
        private System.Windows.Forms.Button btnBrighten;
        private System.Windows.Forms.Button btnInvert;
        private System.Windows.Forms.Button btnBinary;
        private System.Windows.Forms.Button btnConvolution;
        private System.Windows.Forms.NumericUpDown numBrightVal;
        private System.Windows.Forms.NumericUpDown numThreshold;
        private System.Windows.Forms.Button btnSave;
        private System.Windows.Forms.Button btnOpenLoadDir;
        private System.Windows.Forms.Button btnOpenSaveDir;
        private System.Windows.Forms.TextBox txtSavePath;
        private System.Windows.Forms.TextBox txtLoadPath;
    }
}